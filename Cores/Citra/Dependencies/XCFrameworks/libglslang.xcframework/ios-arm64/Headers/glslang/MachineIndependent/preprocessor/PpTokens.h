//
// Copyright (C) 2002-2005  3Dlabs Inc. Ltd.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
//    Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
//    Redistributions in binary form must reproduce the above
//    copyright notice, this list of conditions and the following
//    disclaimer in the documentation and/or other materials provided
//    with the distribution.
//
//    Neither the name of 3Dlabs Inc. Ltd. nor the names of its
//    contributors may be used to endorse or promote products derived
//    from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
// ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
/****************************************************************************\
Copyright (c) 2002, NVIDIA Corporation.

NVIDIA Corporation("NVIDIA") supplies this software to you in
consideration of your agreement to the following terms, and your use,
installation, modification or redistribution of this NVIDIA software
constitutes acceptance of these terms.  If you do not agree with these
terms, please do not use, install, modify or redistribute this NVIDIA
software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, NVIDIA grants you a personal, non-exclusive
license, under NVIDIA's copyrights in this original NVIDIA software (the
"NVIDIA Software"), to use, reproduce, modify and redistribute the
NVIDIA Software, with or without modifications, in source and/or binary
forms; provided that if you redistribute the NVIDIA Software, you must
retain the copyright notice of NVIDIA, this notice and the following
text and disclaimers in all such redistributions of the NVIDIA Software.
Neither the name, trademarks, service marks nor logos of NVIDIA
Corporation may be used to endorse or promote products derived from the
NVIDIA Software without specific prior written permission from NVIDIA.
Except as expressly stated in this notice, no other rights or licenses
express or implied, are granted by NVIDIA herein, including but not
limited to any patent rights that may be infringed by your derivative
works or by other works in which the NVIDIA Software may be
incorporated. No hardware is licensed hereunder.

THE NVIDIA SOFTWARE IS BEING PROVIDED ON AN "AS IS" BASIS, WITHOUT
WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED,
INCLUDING WITHOUT LIMITATION, WARRANTIES OR CONDITIONS OF TITLE,
NON-INFRINGEMENT, MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
ITS USE AND OPERATION EITHER ALONE OR IN COMBINATION WITH OTHER
PRODUCTS.

IN NO EVENT SHALL NVIDIA BE LIABLE FOR ANY SPECIAL, INDIRECT,
INCIDENTAL, EXEMPLARY, CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, LOST PROFITS; PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) OR ARISING IN ANY WAY
OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE
NVIDIA SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT,
TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF
NVIDIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
\****************************************************************************/

#ifndef PARSER_H
#define PARSER_H

namespace glslangA {

// Multi-character tokens
enum EFixedAtoms {
    // single character tokens get their own char value as their token; start here for multi-character tokens
    PpAtomMaxSingle = 127,

    // replace bad character tokens with this, to avoid accidental aliasing with the below
    PpAtomBadToken,

    // Operators

    PPAtomAddAssign,
    PPAtomSubAssign,
    PPAtomMulAssign,
    PPAtomDivAssign,
    PPAtomModAssign,

    PpAtomRight,
    PpAtomLeft,

    PpAtomRightAssign,
    PpAtomLeftAssign,
    PpAtomAndAssign,
    PpAtomOrAssign,
    PpAtomXorAssign,

    PpAtomAnd,
    PpAtomOr,
    PpAtomXor,

    PpAtomEQ,
    PpAtomNE,
    PpAtomGE,
    PpAtomLE,

    PpAtomDecrement,
    PpAtomIncrement,

    PpAtomColonColon,

    PpAtomPaste,

    // Constants

    PpAtomConstInt,
    PpAtomConstUint,
    PpAtomConstInt64,
    PpAtomConstUint64,
    PpAtomConstInt16,
    PpAtomConstUint16,
    PpAtomConstFloat,
    PpAtomConstDouble,
    PpAtomConstFloat16,
    PpAtomConstString,

    // Identifiers
    PpAtomIdentifier,

    // preprocessor "keywords"

    PpAtomDefine,
    PpAtomUndef,

    PpAtomIf,
    PpAtomIfdef,
    PpAtomIfndef,
    PpAtomElse,
    PpAtomElif,
    PpAtomEndif,

    PpAtomLine,
    PpAtomPragma,
    PpAtomError,

    // #version ...
    PpAtomVersion,
    PpAtomCore,
    PpAtomCompatibility,
    PpAtomEs,

    // #extension
    PpAtomExtension,

    // __LINE__, __FILE__, __VERSION__

    PpAtomLineMacro,
    PpAtomFileMacro,
    PpAtomVersionMacro,

    // #include
    PpAtomInclude,

    PpAtomLast,
};

} // end namespace glslangA

#endif /* not PARSER_H */
