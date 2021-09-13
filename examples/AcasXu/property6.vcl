-- Types

pi : Real
pi = 3.141592

type AcasXuInput  = Tensor Real [5]
type AcasXuOutput = Tensor Real [5]

-- The network

network acasXu : AcasXuInput -> AcasXuOutput

-- Inputs

distanceToIntruder : InputVector -> Real
distanceToIntruder x = x ! 0

angleToIntruder : InputVector -> Real
angleToIntruder x = x ! 1

intruderHeading : InputVector -> Real
intruderHeading x = x ! 2

speed : InputVector -> Real
speed x = x ! 3

intruderSpeed : InputVector -> Real
intruderSpeed x = x ! 4

-- Outputs

clearOfConflictScore : InputVector -> Real
clearOfConflictScore x = acasXu x ! 0

-- To do add


-- Property: If the intruder is sufficiently far away, the network advises COC.

intruderFarAway : InputVector -> Prop
intruderFarAway x =
  (-pi <= angleToIntruder x <= -0.7 or 0.7 <= angleToIntruder x <= pi)
  and 12000 <= distanceToIntruder x <= 62000
  and −pi   <= intruderHeading    x <= -pi + 0.005
  and 100   <= speed              x <= 1200
  and 0     <= intruderSpeed      x <= 1200

advisesClearOfConflict : InputVector -> Prop
advisesClearOfConflict x = forall i.
  clearOfConflictScore x <= acasXu x ! i

property6 : Prop
property6 = forall x : InputVector.
  intruderFarAway x => advisesClearOfConflict x