-- WARNING: This file was generated automatically by Vehicle
-- and should not be modified manually!
-- Metadata
--  - Agda version: 2.6.2
--  - AISEC version: 0.1.0.1
--  - Time generated: ???

{-# OPTIONS --allow-exec #-}

open import Vehicle
open import Vehicle.Data.Tensor
open import Data.Product
open import Data.Integer as ℤ using (ℤ)
open import Data.Rational as ℚ using (ℚ)
open import Data.Fin as Fin using (Fin; #_)
open import Data.List
open import Data.Vec.Functional

module windController-temp-output where

InputVector : Set
InputVector = Tensor ℚ (2 ∷ [])

currentSensor[Index-2] : Fin 2
currentSensor[Index-2] = # 0

previousSensor[Index-2] : Fin 2
previousSensor[Index-2] = # 1

postulate controller : InputVector → Tensor ℚ (1 ∷ [])

SafeInput : InputVector → Set
SafeInput x = ∀ (i : Fin 2) → ℚ.- (ℤ.+ 13 ℚ./ 4) ℚ.≤ x i × x i ℚ.≤ ℤ.+ 13 ℚ./ 4

SafeOutput : InputVector → Set
SafeOutput x = ℚ.- (ℤ.+ 5 ℚ./ 4) ℚ.< (controller x (# 0) ℚ.+ (ℤ.+ 2 ℚ./ 1) ℚ.* x currentSensor[Index-2]) ℚ.- x previousSensor[Index-2] × (controller x (# 0) ℚ.+ (ℤ.+ 2 ℚ./ 1) ℚ.* x currentSensor[Index-2]) ℚ.- x previousSensor[Index-2] ℚ.< ℤ.+ 5 ℚ./ 4

abstract
  safe : ∀ (x : Vector ℚ 2) → SafeInput x → SafeOutput x
  safe = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }