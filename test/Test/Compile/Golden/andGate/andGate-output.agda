-- WARNING: This file was generated automatically by Vehicle
-- and should not be modified manually!
-- Metadata
--  - Agda version: 2.6.2
--  - AISEC version: 0.1.0.1
--  - Time generated: ???

{-# OPTIONS --allow-exec #-}

open import Vehicle
open import Data.Product
open import Data.Integer as ℤ using (ℤ)
open import Data.Rational as ℝ using () renaming (ℚ to ℝ)

module andGate-temp-output where

postulate andGate : ℝ → (ℝ → ℝ)

Truthy : ℝ → Set
Truthy x = x ℝ.≥ ℤ.+ 1 ℝ./ 2

Falsey : ℝ → Set
Falsey x = x ℝ.≤ ℤ.+ 1 ℝ./ 2

ValidInput : ℝ → Set
ValidInput x = ℤ.+ 0 ℝ./ 1 ℝ.≤ x × x ℝ.≤ ℤ.+ 1 ℝ./ 1

CorrectOutput : ℝ → (ℝ → Set)
CorrectOutput x1 x2 = let y = andGate x1 x2 in (Truthy x1 × Truthy x2 → Truthy y) × ((Truthy x1 × Falsey x2 → Falsey y) × ((Falsey x1 × Truthy x2 → Falsey y) × (Falsey x1 × Falsey x2 → Falsey y)))

abstract
  andGateCorrect : ∀ (x1 : ℝ) → ∀ (x2 : ℝ) → ValidInput x1 × ValidInput x2 → CorrectOutput x1 x2
  andGateCorrect = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }