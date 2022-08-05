-- WARNING: This file was generated automatically by Vehicle
-- and should not be modified manually!
-- Metadata
--  - Agda version: 2.6.2
--  - AISEC version: 0.1.0.1
--  - Time generated: ???

{-# OPTIONS --allow-exec #-}

open import Vehicle
open import Data.Fin as Fin using (Fin; #_)
open import Function.Base
open import Relation.Binary.PropositionalEquality

module simple-index-output where

abstract
  eqIndex : (Fin 1 ∋ # 0) ≡ ((Fin 2) ∋ # 1)
  eqIndex = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

abstract
  neqIndex : (Fin 1 ∋ # 0) ≢ (Fin 2 ∋ # 1)
  neqIndex = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

abstract
  leqIndex : (Fin 1 ∋ # 0) Fin.≤ (Fin 2 ∋ # 1)
  leqIndex = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

abstract
  ltIndex : (Fin 1 ∋ # 0) Fin.< (Fin 2 ∋ # 1)
  ltIndex = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

abstract
  geqIndex : (Fin 1 ∋ # 0) Fin.≥ (Fin 2 ∋ # 1)
  geqIndex = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

abstract
  gtIndex : (Fin 1 ∋ # 0) Fin.> (Fin 2 ∋ # 1)
  gtIndex = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }
