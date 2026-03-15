// manic.js - iOS 26 TXM JIT Support Script for Manic EMU Emulator
// Optimized for Manic EMU using Geode.js's infinite loop mode
// Features:
// 1. Only handles brk #0x69 (JIT memory mapping requests)
// 2. Keeps StikDebug connection alive indefinitely
// 3. Supports JIT memory requests for multiple code blocks

function littleEndianHexStringToNumber(hexStr) {
    const bytes = [];
    for (let i = 0; i < hexStr.length; i += 2) {
        bytes.push(parseInt(hexStr.substr(i, 2), 16));
    }
    let num = 0n;
    for (let i = 4; i >= 0; i--) {
        num = (num << 8n) | BigInt(bytes[i]);
    }
    return num;
}

function numberToLittleEndianHexString(num) {
    const bytes = [];
    for (let i = 0; i < 5; i++) {
        bytes.push(Number(num & 0xFFn));
        num >>= 8n;
    }
    while (bytes.length < 8) {
        bytes.push(0);
    }
    return bytes.map(b => b.toString(16).padStart(2, '0')).join('');
}

function littleEndianHexToU32(hexStr) {
    return parseInt(hexStr.match(/../g).reverse().join(''), 16);
}

function getRegisterHex(stopReply, regIndex) {
    const regHex = regIndex.toString(16).padStart(2, '0');
    const match = new RegExp(`${regHex}:(?<reg>[0-9a-f]{16});`).exec(stopReply);
    return match ? match.groups['reg'] : null;
}

function getRegisterNumber(stopReply, regIndex) {
    const regHex = getRegisterHex(stopReply, regIndex);
    return regHex ? littleEndianHexStringToNumber(regHex) : null;
}

function safeReadU32(address) {
    try {
        const response = send_command(`m${address.toString(16)},4`);
        if (!response || response.length !== 8) {
            return null;
        }
        return littleEndianHexToU32(response);
    } catch (_error) {
        return null;
    }
}

function safeReadInstructions(address, countBefore, countAfter) {
    const items = [];
    for (let i = -countBefore; i <= countAfter; i++) {
        const current = address + BigInt(i * 4);
        const instr = safeReadU32(current);
        items.push({ address: current, instruction: instr, isCurrent: i === 0 });
    }
    return items;
}

function formatHex(value) {
    if (value === null || value === undefined) {
        return "n/a";
    }
    return `0x${value.toString(16)}`;
}

function formatInstruction(value) {
    if (value === null || value === undefined) {
        return "n/a";
    }
    return `0x${value.toString(16).padStart(8, '0')}`;
}

function formatExceptionType(metype) {
    switch (metype) {
        case 1:
            return "EXC_BAD_ACCESS";
        case 2:
            return "EXC_BAD_INSTRUCTION";
        case 6:
            return "EXC_BREAKPOINT";
        default:
            return `metype=${metype}`;
    }
}

function findMappedRegion(address) {
    for (const region of mappedRegions) {
        const start = region.address;
        const end = start + region.size;
        if (address >= start && address < end) {
            return region;
        }
    }
    return null;
}

function extractBrkImmediate(u32) {
    return (u32 >> 5) & 0xFFFF;
}

// Check if the instruction is a BRK instruction
// BRK instruction format: 0xD4200000 | (imm16 << 5)
// The upper 16 bits should be 0xD420
function isBrkInstruction(u32) {
    return (u32 >>> 16) === 0xD420;
}

// Format size into a human-readable format
function formatSize(size) {
    if (size >= 1024 * 1024) {
        return `${(size / (1024 * 1024)).toFixed(2)} MB`;
    } else if (size >= 1024) {
        return `${(size / 1024).toFixed(2)} KB`;
    }
    return `${size} bytes`;
}

log(`[Manic EMU] ========================================`);
log(`[Manic EMU] Manic EMU iOS 26 TXM JIT Support Script`);
log(`[Manic EMU] ========================================`);

let pid = get_pid();
log(`[Manic EMU] pid = ${pid}`);
let attachResponse = send_command(`vAttach;${pid.toString(16)}`);
log(`[Manic EMU] attach_response = ${attachResponse}`);

let validBreakpoints = 0;
let totalBreakpoints = 0;
let totalMemoryMapped = 0n;
let lastNonBreakpointSignature = null;
let lastNonBreakpointCount = 0;

    // Track processed memory areas for debugging.
let mappedRegions = [];

// Infinite Loop - StikDebug Must Stay Connected in TXM Mode
// The Manic EMU emulator dynamically creates multiple code blocks, each of which needs to be marked as executable by StikDebug.
log(`[Manic EMU] Starting infinite loop - StikDebug will stay connected`);
log(`[Manic EMU] Waiting for JIT memory requests (brk #0x69)...`);

while (true) {
    totalBreakpoints++;
    
    let brkResponse = send_command(`c`);
    
    // Check Exception Types (metype)
    // metype:6 = EXC_BREAKPOINT
    let metypeMatch = /metype:(\d+)/.exec(brkResponse);
    let metype = metypeMatch ? parseInt(metypeMatch[1]) : -1;
    
    // If it's not a breakpoint exception, log enough state to identify whether
    // we're executing from the RX cache, the RW alias, or some bogus pointer.
    if (metype !== 6 && metype !== -1) {
        const pcNum = getRegisterNumber(brkResponse, 0x20);
        const x16Num = getRegisterNumber(brkResponse, 0x10);
        const x17Num = getRegisterNumber(brkResponse, 0x11);
        const x18Num = getRegisterNumber(brkResponse, 0x12);
        const x19Num = getRegisterNumber(brkResponse, 0x13);
        const x0Num = getRegisterNumber(brkResponse, 0x00);
        const x1Num = getRegisterNumber(brkResponse, 0x01);
        const x2Num = getRegisterNumber(brkResponse, 0x02);
        const x3Num = getRegisterNumber(brkResponse, 0x03);
        const x24Num = getRegisterNumber(brkResponse, 0x18);
        const x25Num = getRegisterNumber(brkResponse, 0x19);
        const x29Num = getRegisterNumber(brkResponse, 0x1d);
        const x30Num = getRegisterNumber(brkResponse, 0x1e);
        const instrU32 = pcNum !== null ? safeReadU32(pcNum) : null;
        const nearbyInstructions = pcNum !== null ? safeReadInstructions(pcNum, 2, 2) : [];
        const region = pcNum !== null ? findMappedRegion(pcNum) : null;
        const signature = `${metype}:${pcNum !== null ? pcNum.toString(16) : 'nopc'}:${instrU32 !== null ? instrU32.toString(16) : 'noinsn'}`;

        if (signature === lastNonBreakpointSignature) {
            lastNonBreakpointCount++;
        } else {
            lastNonBreakpointSignature = signature;
            lastNonBreakpointCount = 1;
        }

        if (lastNonBreakpointCount <= 5 || (lastNonBreakpointCount % 50) === 0) {
            log(`[Manic EMU] Non-breakpoint exception: ${formatExceptionType(metype)} (${metype})`);
            log(`[Manic EMU]   PC: ${formatHex(pcNum)}  instr: ${formatInstruction(instrU32)}  repeat: ${lastNonBreakpointCount}`);
            log(`[Manic EMU]   x0=${formatHex(x0Num)} x1=${formatHex(x1Num)} x2=${formatHex(x2Num)} x3=${formatHex(x3Num)}`);
            log(`[Manic EMU]   x16=${formatHex(x16Num)} x17=${formatHex(x17Num)} x18=${formatHex(x18Num)} x19=${formatHex(x19Num)}`);
            log(`[Manic EMU]   x24=${formatHex(x24Num)} x25=${formatHex(x25Num)}`);
            log(`[Manic EMU]   x29=${formatHex(x29Num)} x30=${formatHex(x30Num)}`);
            if (region) {
                log(`[Manic EMU]   PC is inside JIT RX region #${region.index} (${formatHex(region.address)} - ${formatHex(region.address + region.size)})`);
            } else {
                log(`[Manic EMU]   PC is outside all prepared JIT RX regions`);
            }
            if (nearbyInstructions.length > 0) {
                const window = nearbyInstructions.map(item => {
                    const marker = item.isCurrent ? '*' : ' ';
                    return `${marker}${formatHex(item.address)}:${formatInstruction(item.instruction)}`;
                }).join(' ');
                log(`[Manic EMU]   Nearby: ${window}`);
            }
        }
        continue;
    }
    
    let tidMatch = /T[0-9a-f]+thread:(?<tid>[0-9a-f]+);/.exec(brkResponse);
    let tid = tidMatch ? tidMatch.groups['tid'] : null;
    let pc = getRegisterHex(brkResponse, 0x20);
    let x0 = getRegisterHex(brkResponse, 0x00);
    let x1 = getRegisterHex(brkResponse, 0x01);
    
    if (!tid || !pc || !x0) {
        log(`[Manic EMU] Failed to extract registers, continuing...`);
        continue;
    }

    const pcNum = littleEndianHexStringToNumber(pc);
    const x0Num = littleEndianHexStringToNumber(x0);
    const x1Num = x1 ? littleEndianHexStringToNumber(x1) : 0n;
    
    let instrU32 = safeReadU32(pcNum);
    if (instrU32 === null) {
        log(`[Manic EMU] Failed to read instruction at PC=0x${pcNum.toString(16)}, continuing...`);
        continue;
    }
    
    // Check if it's a BRK instruction.
    if (!isBrkInstruction(instrU32)) {
        // Not a BRK instruction, skip it.
        log(`[Manic EMU] Not a BRK instruction at PC=0x${pcNum.toString(16)}, skipping...`);
        continue;
    }
    
    let brkImmediate = extractBrkImmediate(instrU32);
    
    // Only handle brk #0x69 (JIT memory mapping request).
    if (brkImmediate === 0x69) {
        validBreakpoints++;
        
        let jitPageAddress = x0Num;
        // If x1 is 0, use the default size of 64KB (0x10000).
        // Manic EMU's CodeBlock typically requests large memory chunks (tens of MB for CPU JIT)
        // but also asks for smaller ones (like 4KB/16KB for SpinLock and Shader JIT).
        let size = x1Num > 0n ? x1Num : 0x10000n;
        
        log(`[Manic EMU] ----------------------------------------`);
        log(`[Manic EMU] JIT Request #${validBreakpoints}`);
        log(`[Manic EMU]   Address: 0x${jitPageAddress.toString(16)}`);
        log(`[Manic EMU]   Size: 0x${size.toString(16)} (${formatSize(Number(size))})`);
        
        // Call prepare_memory_region to mark the memory as executable.
        let prepareJITPageResponse = prepare_memory_region(Number(jitPageAddress), Number(size));
        log(`[Manic EMU]   prepare_memory_region result: ${prepareJITPageResponse}`);
        
        // Log statistics
        totalMemoryMapped += size;
        mappedRegions.push({
            address: jitPageAddress,
            size,
            index: validBreakpoints
        });
        
        log(`[Manic EMU]   Total JIT memory mapped: ${formatSize(Number(totalMemoryMapped))}`);
        
        // Set PC+4 to continue program execution
        let pcPlus4 = numberToLittleEndianHexString(pcNum + 4n);
        send_command(`P20=${pcPlus4};thread:${tid};`);
        
        log(`[Manic EMU]   Resumed execution at PC=0x${(pcNum + 4n).toString(16)}`);
        log(`[Manic EMU] ----------------------------------------`);
        
    } else if (brkImmediate === 0x70 || brkImmediate === 0x71) {
        // brk #0x70 and brk #0x71 are breakpoints used by some debuggers.
        // Skip directly to PC+4 and continue execution.
        log(`[Manic EMU] Debug breakpoint brk #0x${brkImmediate.toString(16)} at PC=0x${pcNum.toString(16)}, skipping...`);
        let pcPlus4 = numberToLittleEndianHexString(pcNum + 4n);
        send_command(`P20=${pcPlus4};thread:${tid};`);
        
    } else {
        // Other BRK instructions, skip PC+4 and continue execution.
        log(`[Manic EMU] Unknown brk #0x${brkImmediate.toString(16)} at PC=0x${pcNum.toString(16)}, skipping...`);
        let pcPlus4 = numberToLittleEndianHexString(pcNum + 4n);
        send_command(`P20=${pcPlus4};thread:${tid};`);
    }
}

// This line of code will never run because it's an infinite loop
// log(`[Manic EMU] Script ended`);
