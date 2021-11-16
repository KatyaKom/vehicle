-- WARNING: This file was generated automatically by Vehicle
-- and should not be modified manually!
-- Metadata
--  - Agda version: 2.6.2
--  - AISEC version: 0.1.0.1
--  - Time generated: ???

open import AISEC.Utils
open import Data.Real as ℝ using (ℝ)
open import Data.List

module MyTestModule where

f : Tensor ℝ (1 ∷ []) → Tensor ℝ (1 ∷ [])
f = evaluate record
  { databasePath = DATABASE_PATH
  ; networkUUID  = NETWORK_UUID
  }

monotonic : ∀ (x1 : Tensor ℝ (1 ∷ [])) → ∀ (x2 : Tensor ℝ (1 ∷ [])) → let y1 = f (x1)
y2 = f (x2) in x1 0 ℝ.≤ x2 0 → y1 0 ℝ.≤ y2 0
monotonic = checkProperty record
  { databasePath = DATABASE_PATH
  ; propertyUUID = ????
  }