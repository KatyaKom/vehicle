network f : Rat -> Tensor Rat [4]

dataset d : List (Fin 4)

spec : Prop
spec = forall i in d . f 0.0 ! i >= 0