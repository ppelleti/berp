{-# LANGUAGE Trustworthy #-}
{-# OPTIONS_GHC -funbox-strict-fields #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Berp.Base.LegacyHash
-- Copyright   :  (c) The University of Glasgow 2003
-- License     :  See the GHC license below.
--
-- Maintainer  :  (of this branch) florbitous@gmail.com
-- Stability   :  provisional
-- Portability :  portable
--
-- Ported hashString from base-4.6.0.0, since it is not included in
-- the more recent base libraries.
--
-----------------------------------------------------------------------------

{-
The Glasgow Haskell Compiler License

Copyright 2004, The University Court of the University of Glasgow.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

- Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

- Neither name of the University nor the names of its contributors may be
used to endorse or promote products derived from this software without
specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE UNIVERSITY COURT OF THE UNIVERSITY OF
GLASGOW AND THE CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
UNIVERSITY COURT OF THE UNIVERSITY OF GLASGOW OR THE CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
DAMAGE.
-}

module Berp.Base.LegacyHash (hashString) where

import Data.Bits (shiftR)
import Data.Char (ord)
import Data.List (foldl')
import Data.Int (Int32, Int64)

-- | A sample hash function for Strings.  We keep multiplying by the
-- golden ratio and adding.  The implementation is:
--
-- > hashString = foldl' f golden
-- >   where f m c = fromIntegral (ord c) * magic + hashInt32 m
-- >         magic = 0xdeadbeef
--
-- Where hashInt32 works just as hashInt shown above.
--
-- Knuth argues that repeated multiplication by the golden ratio
-- will minimize gaps in the hash space, and thus it's a good choice
-- for combining together multiple keys to form one.
--
-- Here we know that individual characters c are often small, and this
-- produces frequent collisions if we use ord c alone.  A
-- particular problem are the shorter low ASCII and ISO-8859-1
-- character strings.  We pre-multiply by a magic twiddle factor to
-- obtain a good distribution.  In fact, given the following test:
--
-- > testp :: Int32 -> Int
-- > testp k = (n - ) . length . group . sort . map hs . take n $ ls
-- >   where ls = [] : [c : l | l <- ls, c <- ['\0'..'\xff']]
-- >         hs = foldl' f golden
-- >         f m c = fromIntegral (ord c) * k + hashInt32 m
-- >         n = 100000
--
-- We discover that testp magic = 0.

hashString :: String -> Int32
hashString = foldl' f golden
   where f m c = fromIntegral (ord c) * magic + hashInt32 m
         magic = 0xdeadbeef

golden :: Int32
golden = 1013904242 -- = round ((sqrt 5 - 1) * 2^32) :: Int32
-- was -1640531527 = round ((sqrt 5 - 1) * 2^31) :: Int32
-- but that has bad mulHi properties (even adding 2^32 to get its inverse)
-- Whereas the above works well and contains no hash duplications for
-- [-32767..65536]

-- | A sample (and useful) hash function for Int and Int32,
-- implemented by extracting the uppermost 32 bits of the 64-bit
-- result of multiplying by a 33-bit constant.  The constant is from
-- Knuth, derived from the golden ratio:
--
-- > golden = round ((sqrt 5 - 1) * 2^32)
--
-- We get good key uniqueness on small inputs
-- (a problem with previous versions):
--  (length $ group $ sort $ map hashInt [-32767..65536]) == 65536 + 32768
--
hashInt32 :: Int32 -> Int32
hashInt32 x = mulHi x golden + x

-- hi 32 bits of a x-bit * 32 bit -> 64-bit multiply
mulHi :: Int32 -> Int32 -> Int32
mulHi a b = fromIntegral (r `shiftR` 32)
   where r :: Int64
         r = fromIntegral a * fromIntegral b