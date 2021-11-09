module Vehicle.Language.AST.Visibility where

import GHC.Generics (Generic)
import Control.DeepSeq (NFData)

import Vehicle.Prelude

--------------------------------------------------------------------------------
-- Definitions

-- | Visibility of function arguments.
data Visibility = Explicit | Implicit | Instance
  deriving (Eq, Ord, Show, Generic)

instance NFData Visibility

instance Pretty Visibility where
  pretty = \case
    Explicit -> "Explicit"
    Implicit -> "Implicit"
    Instance -> "Instance"

visBrackets :: Visibility -> Doc a -> Doc a
visBrackets Explicit = id
visBrackets Implicit = braces
visBrackets Instance = braces . braces

visProv :: Visibility -> Provenance -> Provenance
visProv Explicit = id
visProv Implicit = expandProvenance (1,1)
visProv Instance = expandProvenance (2,2)

-- | Type class for types which have provenance information

class HasVisibility a where
  visibilityOf :: a -> Visibility

--------------------------------------------------------------------------------
-- Ownership

data Owner
  = TheUser
  | TheMachine
  deriving (Eq, Show, Ord, Generic)

instance NFData Owner

class HasOwner a where
  ownerOf :: a -> Owner