{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE UndecidableInstances #-}
--------------------------------------------------------------------
-- |
-- Module    : Data.Vector.Binary
-- Copyright : (c) Don Stewart 2010-2012

-- License   : BSD3
--
-- Maintainer: Don Stewart <dons00@gmail.com>
-- Stability : provisional
-- Portability: GHC only

-- Instances for Binary for the types defined in the vector package,
-- making it easy to serialize vectors to and from disk. We use the
-- generic interface to vectors, so all vector types are supported.
--
-- To serialize a vector:
--
-- > *Data.Vector.Binary> let v = Data.Vector.fromList [1..10]
-- > *Data.Vector.Binary> v
-- > fromList [1,2,3,4,5,6,7,8,9,10] :: Data.Vector.Vector
-- > *Data.Vector.Binary> encode v
-- > Chunk "\NUL\NUL\NUL\NUL\NUL...\NUL\NUL\NUL\t\NUL\NUL\NUL\NUL\n" Empty
--
-- Which you can in turn compress before writing to disk:
--
-- > compress . encode $ v
-- > Chunk "\US\139\b\NUL\NUL\N...\229\240,\254:\NUL\NUL\NUL" Empty
--
--------------------------------------------------------------------

module Data.Vector.Binary () where

import Data.Binary
import Control.Monad

import qualified Data.Vector.Generic as G
import qualified Data.Vector.Unboxed as U
import qualified Data.Vector.Storable as S
import Data.Vector (Vector)

import System.IO.Unsafe
import qualified Data.Vector.Generic.Mutable as M
import Foreign.Storable (Storable)

-- Enumerate the instances to avoid the nasty overlapping instances.

-- | Boxed, generic vectors.
instance Binary a => Binary (Vector a) where
    put = putGeneric
    get = getGeneric
    {-# INLINE get #-}

-- | Unboxed vectors
instance (U.Unbox a, Binary a) => Binary (U.Vector a) where
    put = putGeneric
    get = getGeneric
    {-# INLINE get #-}

-- | Storable vectors
instance (Storable a, Binary a) => Binary (S.Vector a) where
    put = putGeneric
    get = getGeneric
    {-# INLINE get #-}

------------------------------------------------------------------------

-- this is morally sound, if very awkward.
-- all effects are contained, and can't escape the unsafeFreeze
getGeneric :: (G.Vector v a, Binary a) => Get (v a)
{-# INLINE getGeneric #-}
getGeneric = do
    n  <- get

    -- new unitinialized array
    mv <- lift $ M.new n

    let fill i
            | i < n = do
                x <- get
                (unsafePerformIO $ M.unsafeWrite mv i x) `seq` return ()
                fill (i+1)

            | otherwise = return ()

    fill 0

    lift $ G.unsafeFreeze mv

-- | Generic put for anything in the G.Vector class.
putGeneric :: (G.Vector v a, Binary a) => v a -> Put
{-# INLINE putGeneric #-}
putGeneric v = do
    put (G.length v)
    G.mapM_ put v

lift :: IO b -> Get b
lift = return .unsafePerformIO