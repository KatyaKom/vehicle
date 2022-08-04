-- WARNING: This file was generated automatically by Vehicle
-- and should not be modified manually!
-- Metadata
--  - Agda version: 2.6.2
--  - AISEC version: 0.1.0.1
--  - Time generated: ???

{-# OPTIONS --allow-exec #-}

open import Vehicle
open import Data.Unit
open import Data.Integer as ℤ using (ℤ)
open import Data.List
open import Data.List.Relation.Unary.All as List
open import Relation.Binary.PropositionalEquality

module simple-quantifierIn-temp-output where

emptyList : List ℤ
emptyList = []

abstract
  empty : List.All (λ (x : ℤ) → ⊤) emptyList
  empty = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

abstract
  double : List.All (λ (x : ℤ) → List.All (λ (y : ℤ) → x ≡ y) emptyList) emptyList
  double = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

abstract
  forallForallIn : ∀ (x : ℤ) → List.All (λ (y : ℤ) → x ≡ y) emptyList
  forallForallIn = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

abstract
  forallInForall : List.All (λ (x : ℤ) → ∀ (y : ℤ) → x ≡ y) emptyList
  forallInForall = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }