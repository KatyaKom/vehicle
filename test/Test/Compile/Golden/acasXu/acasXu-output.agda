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
open import Data.Sum
open import Data.Integer as ℤ using (ℤ)
open import Data.Rational as ℚ using (ℚ)
open import Data.Fin as Fin using (Fin; #_)
open import Data.List
open import Relation.Binary.PropositionalEquality
open import Relation.Nullary

module acasXu-temp-output where

InputVector : Set
InputVector = Tensor ℚ (5 ∷ [])

distanceToIntruder : Fin 5
distanceToIntruder = # 0

angleToIntruder : Fin 5
angleToIntruder = # 1

intruderHeading : Fin 5
intruderHeading = # 2

speed : Fin 5
speed = # 3

intruderSpeed : Fin 5
intruderSpeed = # 4

OutputVector : Set
OutputVector = Tensor ℚ (5 ∷ [])

clearOfConflict : Fin 5
clearOfConflict = # 0

weakLeft : Fin 5
weakLeft = # 1

weakRight : Fin 3
weakRight = # 2

strongLeft : Fin 5
strongLeft = # 3

strongRight : Fin 5
strongRight = # 4

postulate acasXu : InputVector → OutputVector

pi : ℚ
pi = ℤ.+ 392699 ℚ./ 125000

Advises : Fin 5 → (InputVector → Set)
Advises i x = ∀ (j : Fin 5) → i ≢ j → acasXu x i ℚ.< acasXu x j

IntruderDistantAndSlower : InputVector → Set
IntruderDistantAndSlower x = x distanceToIntruder ℚ.≥ ℤ.+ 55947691 ℚ./ 1000 × (x speed ℚ.≥ ℤ.+ 1145 ℚ./ 1 × x intruderSpeed ℚ.≤ ℤ.+ 60 ℚ./ 1)

abstract
  property1 : ∀ (x : Tensor ℚ (5 ∷ [])) → IntruderDistantAndSlower x → acasXu x clearOfConflict ℚ.≤ ℤ.+ 1500 ℚ./ 1
  property1 = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

abstract
  property2 : ∀ (x : Tensor ℚ (5 ∷ [])) → IntruderDistantAndSlower x → ∃ λ (j : Fin 5) → acasXu x j ℚ.> acasXu x clearOfConflict
  property2 = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

DirectlyAhead : InputVector → Set
DirectlyAhead x = (ℤ.+ 1500 ℚ./ 1 ℚ.≤ x distanceToIntruder × x distanceToIntruder ℚ.≤ ℤ.+ 1800 ℚ./ 1) × (ℚ.- (ℤ.+ 3 ℚ./ 50) ℚ.≤ x angleToIntruder × x angleToIntruder ℚ.≤ ℤ.+ 3 ℚ./ 50)

MovingTowards : InputVector → Set
MovingTowards x = x intruderHeading ℚ.≥ ℤ.+ 31 ℚ./ 10 × (x speed ℚ.≥ ℤ.+ 980 ℚ./ 1 × x intruderSpeed ℚ.≥ ℤ.+ 960 ℚ./ 1)

abstract
  property3 : ∀ (x : Tensor ℚ (5 ∷ [])) → DirectlyAhead x × MovingTowards x → ¬ Advises clearOfConflict x
  property3 = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

MovingAway : InputVector → Set
MovingAway x = x intruderHeading ≡ ℤ.+ 0 ℚ./ 1 × (ℤ.+ 1000 ℚ./ 1 ℚ.≤ x speed × (ℤ.+ 700 ℚ./ 1 ℚ.≤ x intruderSpeed × x intruderSpeed ℚ.≤ ℤ.+ 800 ℚ./ 1))

abstract
  property4 : ∀ (x : Tensor ℚ (5 ∷ [])) → DirectlyAhead x × MovingAway x → ¬ Advises clearOfConflict x
  property4 = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

NearAndApproachingFromLeft : InputVector → Set
NearAndApproachingFromLeft x = (ℤ.+ 250 ℚ./ 1 ℚ.≤ x distanceToIntruder × x distanceToIntruder ℚ.≤ ℤ.+ 400 ℚ./ 1) × ((ℤ.+ 1 ℚ./ 5 ℚ.≤ x angleToIntruder × x angleToIntruder ℚ.≤ ℤ.+ 2 ℚ./ 5) × ((ℚ.- pi ℚ.≤ x intruderHeading × x intruderHeading ℚ.≤ ℚ.- pi ℚ.+ ℤ.+ 1 ℚ./ 200) × ((ℤ.+ 100 ℚ./ 1 ℚ.≤ x speed × x speed ℚ.≤ ℤ.+ 400 ℚ./ 1) × (ℤ.+ 0 ℚ./ 1 ℚ.≤ x intruderSpeed × x intruderSpeed ℚ.≤ ℤ.+ 400 ℚ./ 1))))

abstract
  property5 : ∀ (x : Tensor ℚ (5 ∷ [])) → NearAndApproachingFromLeft x → Advises strongRight x
  property5 = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

IntruderFarAway : InputVector → Set
IntruderFarAway x = (ℤ.+ 12000 ℚ./ 1 ℚ.≤ x distanceToIntruder × x distanceToIntruder ℚ.≤ ℤ.+ 62000 ℚ./ 1) × ((ℚ.- pi ℚ.≤ x angleToIntruder × x angleToIntruder ℚ.≤ ℚ.- (ℤ.+ 7 ℚ./ 10) ⊎ ℤ.+ 7 ℚ./ 10 ℚ.≤ x angleToIntruder × x angleToIntruder ℚ.≤ pi) × ((ℚ.- pi ℚ.≤ x intruderHeading × x intruderHeading ℚ.≤ ℚ.- pi ℚ.+ ℤ.+ 1 ℚ./ 200) × ((ℤ.+ 100 ℚ./ 1 ℚ.≤ x speed × x speed ℚ.≤ ℤ.+ 1200 ℚ./ 1) × (ℤ.+ 0 ℚ./ 1 ℚ.≤ x intruderSpeed × x intruderSpeed ℚ.≤ ℤ.+ 1200 ℚ./ 1))))

abstract
  property6 : ∀ (x : Tensor ℚ (5 ∷ [])) → IntruderFarAway x → Advises clearOfConflict x
  property6 = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

LargeVerticalSeparation : InputVector → Set
LargeVerticalSeparation x = (ℤ.+ 0 ℚ./ 1 ℚ.≤ x distanceToIntruder × x distanceToIntruder ℚ.≤ ℤ.+ 60760 ℚ./ 1) × ((ℚ.- pi ℚ.≤ x angleToIntruder × x angleToIntruder ℚ.≤ pi) × ((ℚ.- pi ℚ.≤ x intruderHeading × x intruderHeading ℚ.≤ pi) × ((ℤ.+ 100 ℚ./ 1 ℚ.≤ x speed × x speed ℚ.≤ ℤ.+ 1200 ℚ./ 1) × (ℤ.+ 0 ℚ./ 1 ℚ.≤ x intruderSpeed × x intruderSpeed ℚ.≤ ℤ.+ 1200 ℚ./ 1))))

abstract
  property7 : ∀ (x : Tensor ℚ (5 ∷ [])) → LargeVerticalSeparation x → ¬ Advises strongLeft x × ¬ Advises strongRight x
  property7 = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

LargeVerticalSeparationAndPreviousWeakLeft : InputVector → Set
LargeVerticalSeparationAndPreviousWeakLeft x = (ℤ.+ 0 ℚ./ 1 ℚ.≤ x distanceToIntruder × x distanceToIntruder ℚ.≤ ℤ.+ 60760 ℚ./ 1) × ((ℚ.- pi ℚ.≤ x angleToIntruder × x angleToIntruder ℚ.≤ ℚ.- (ℤ.+ 3 ℚ./ 4) ℚ.* pi) × ((ℚ.- (ℤ.+ 1 ℚ./ 10) ℚ.≤ x intruderHeading × x intruderHeading ℚ.≤ ℤ.+ 1 ℚ./ 10) × ((ℤ.+ 600 ℚ./ 1 ℚ.≤ x speed × x speed ℚ.≤ ℤ.+ 1200 ℚ./ 1) × (ℤ.+ 600 ℚ./ 1 ℚ.≤ x intruderSpeed × x intruderSpeed ℚ.≤ ℤ.+ 1200 ℚ./ 1))))

abstract
  property8 : ∀ (x : Tensor ℚ (5 ∷ [])) → LargeVerticalSeparationAndPreviousWeakLeft x → Advises clearOfConflict x ⊎ Advises weakLeft x
  property8 = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

PreviousWeakRightAndNearbyIntruder : InputVector → Set
PreviousWeakRightAndNearbyIntruder x = (ℤ.+ 2000 ℚ./ 1 ℚ.≤ x distanceToIntruder × x distanceToIntruder ℚ.≤ ℤ.+ 7000 ℚ./ 1) × ((ℚ.- (ℤ.+ 2 ℚ./ 5) ℚ.≤ x angleToIntruder × x angleToIntruder ℚ.≤ ℚ.- (ℤ.+ 7 ℚ./ 50)) × ((ℚ.- pi ℚ.≤ x intruderHeading × x intruderHeading ℚ.≤ ℚ.- pi ℚ.+ ℤ.+ 1 ℚ./ 100) × ((ℤ.+ 100 ℚ./ 1 ℚ.≤ x speed × x speed ℚ.≤ ℤ.+ 150 ℚ./ 1) × (ℤ.+ 0 ℚ./ 1 ℚ.≤ x intruderSpeed × x intruderSpeed ℚ.≤ ℤ.+ 150 ℚ./ 1))))

abstract
  property9 : ∀ (x : Tensor ℚ (5 ∷ [])) → PreviousWeakRightAndNearbyIntruder x → Advises strongLeft x
  property9 = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }

IntruderFarAway2 : InputVector → Set
IntruderFarAway2 x = (ℤ.+ 36000 ℚ./ 1 ℚ.≤ x distanceToIntruder × x distanceToIntruder ℚ.≤ ℤ.+ 60760 ℚ./ 1) × ((ℤ.+ 7 ℚ./ 10 ℚ.≤ x angleToIntruder × x angleToIntruder ℚ.≤ pi) × ((ℚ.- pi ℚ.≤ x intruderHeading × x intruderHeading ℚ.≤ ℚ.- pi ℚ.+ ℤ.+ 1 ℚ./ 100) × ((ℤ.+ 900 ℚ./ 1 ℚ.≤ x speed × x speed ℚ.≤ ℤ.+ 1200 ℚ./ 1) × (ℤ.+ 600 ℚ./ 1 ℚ.≤ x intruderSpeed × x intruderSpeed ℚ.≤ ℤ.+ 1200 ℚ./ 1))))

abstract
  property10 : ∀ (x : Tensor ℚ (5 ∷ [])) → IntruderFarAway2 x → Advises clearOfConflict x
  property10 = checkSpecification record
    { proofCache   = "/home/matthew/Code/AISEC/vehicle/proofcache.vclp"
    }