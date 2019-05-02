module Objects

import Graphics.SDL2
import Data.AVL.Dict
import Physics.Vector2D

import Descriptors
import Resources

%access public export


data MoveDirection = Leftward | Rightward
%name MoveDirection direction

Show MoveDirection where
  show Leftward = "left"
  show Rightward = "right"

record ControlState where
  constructor MkControlState
  moving : Maybe MoveDirection
  jumping : Bool
  attacking : Bool
%name ControlState controlState

Show ControlState where
  show (MkControlState moving jumping attacking)
    = "(moving: " ++ (show moving) ++ "," ++
      " jumping: " ++ (show jumping) ++ "," ++
      " attacking: " ++ (show attacking) ++ ")"

noControl : ControlState
noControl = MkControlState Nothing False False

startMoving : (direction : MoveDirection) -> ControlState -> ControlState
startMoving direction = record { moving = Just direction }

stopMoving : ControlState -> ControlState
stopMoving = record { moving = Nothing }

startJumping : ControlState -> ControlState
startJumping = record { jumping = True }

stopJumping : ControlState -> ControlState
stopJumping = record { jumping = False }

startAttacking : ControlState -> ControlState
startAttacking = record { attacking = True }

stopAttacking : ControlState -> ControlState
stopAttacking = record { attacking = False }


record PhysicsProperties where
  constructor MkPhysicsProperties
  position : Vector2D
  dimensions : Vector2D
  angle : Double
  density : Double
  friction : Double
  mass : Double -- overwritten on Scene.addBody
  type : BodyType

data CompleteRenderDescriptor
  = DrawBox ResourceReference
  | TileWith ResourceReference Vector2D (Nat, Nat)
  | Invisible

-- all changes -> physics, physics -> objects
record Object where
  constructor MkObject
  id : String
  name : String
  physicsProperties : PhysicsProperties
  controlState : ControlState
  renderDescription : CompleteRenderDescriptor
  tags : List ObjectTag

%name Object object

Show Object where
  show (MkObject id name physicsProperties controlState renderDescription tags) = "{ object | "
    ++   "id: " ++ id
    ++ ", name: " ++ name
    ++ ", controlState: " ++ show controlState
    ++ ", tags: " ++ show tags
    ++ " }"

export
physicsUpdate : (PhysicsProperties -> PhysicsProperties) -> Object -> Object
physicsUpdate f = record { physicsProperties $= f }

export
angle : Object -> Double
angle = angle . physicsProperties

export
mass : Object -> Double
mass = mass . physicsProperties

export
dimensions : Object -> Vector2D
dimensions = dimensions . physicsProperties

export
dim : Object -> Vector2D
dim = dimensions

export
position : Object -> Vector2D
position = position . physicsProperties

export
w : Object -> Double
w = fst . dimensions

export
h : Object -> Double
h = snd . dimensions

export
x : Object -> Double
x = fst . position

export
y : Object -> Double
y = snd . position
