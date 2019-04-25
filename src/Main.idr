module Main

import Graphics.SDL2 as SDL2
import System as System
import Control.ST
import Control.ST.ImplicitCall
import Data.AVL.Dict
import Physics.Box2D
import Language.JSON

import Draw
import Scene
import Objects
import Events
import Input
import Physics.Vector2D
import Physics.Box2D
import GameIO
import Resources
import Descriptors

GameState : (Monad m, GameIO m, Draw m, ConsoleIO m, Box2DPhysics m, Scene m) => Type
GameState {m} = Composite [SDraw {m},
                           SScene {m},
                           State Vector2D,
                           SCache {m} {r=Texture},
                           State Int]

screenScale : Double
screenScale = 33

resolution : (Int, Int)
resolution = (1280, 960)

Cast (Int, Int) (Double, Double) where
  cast (x, y) = (cast x, cast y)

resolution' : (Double, Double)
resolution' = cast resolution

positionToScreen : (camera : Vector2D) -> (position : Vector2D) -> (Int, Int)
positionToScreen (cx, cy) (ox, oy)
  = let (x, y) = screenScale `scale` (ox - cx, cy - oy) in
        cast (x + (fst resolution')/2, y + (snd resolution')/2)

dimToScreen : (dim : Vector2D) -> (Int, Int)
dimToScreen (x, y) = cast $ (screenScale * x, screenScale * y)

drawScene : (Monad m,
             ConsoleIO m,
             Box2DPhysics m,
             GameIO m,
             Scene m,
             Draw m) =>
             (state : Var) ->
             ST m () [state ::: GameState {m}]
drawScene state = (with ST do
  [draw, scene, camera, textureCache, lastms] <- split state
  clear draw
  drawObjects draw !(read camera) !(getObjects scene) textureCache
  present draw
  combine state [draw, scene, camera, textureCache, lastms]) where
    drawObjects : (Draw m, ConsoleIO m) =>
                  (draw : Var) -> (camera : Vector2D) -> List Object -> (cache : Var) ->
                  ST m () [cache ::: SCache {m} {r=Texture}, draw ::: SDraw {m}]
    drawObjects draw camera [] cache = pure ()
    drawObjects {m} draw camera (object :: xs) cache = (with ST do
      let (w, h) = dimToScreen $ 2 `scale` (dim object)
      let (x, y) = positionToScreen camera (position object)
      let deg_angle = (angle object) / (2*pi) * 360.0
      case renderDescription object of
        DrawBox textureRef => with ST do
          Just texture <- get {m} {r=Texture} cache draw textureRef | Nothing => ?noTextureDrawBox
          let (w', h') = dimToScreen (dim object)
          drawWholeCenter draw texture (MkSDLRect (x - w') (y - h') w h) deg_angle
          -- drawWholeCenter draw texture (MkSDLRect x y w h) deg_angle -- TODO why doesn't this work?
          drawObjects draw camera xs cache
        TileWith textureRef tileDims => with ST do
          let (tw, th) = dimToScreen $ 2 `scale` tileDims
          Just texture <- get {m} {r=Texture} cache draw textureRef | Nothing => ?noTexture
          putStrLn $ "tile at " ++ show (x, y) ++ ", whole dim " ++ show (w, h) ++ ", tile dim " ++ show (tw, th)

          drawObjects draw camera xs cache)

loop : (Monad m,
        ConsoleIO m,
        Box2DPhysics m,
        GameIO m,
        Scene m,
        Draw m) =>
        (state : Var) ->
        ST m () [state ::: GameState {m}]
loop state = with ST do
  Right events <- poll
               | pure ()
  [draw, scene, camera, textureCache, lastms] <- split state
  controlEvent scene "player" (case events of -- TODO tf is this
                                    [] => Nothing
                                    (x :: xs) => Just x)

  beforems <- ticks
  iterate scene (beforems - !(read lastms))
  write lastms beforems
  combine state [draw, scene, camera, textureCache, lastms]
  drawScene state
  loop state

game : (Monad m, ConsoleIO m, Draw m, GameIO m, Box2DPhysics m, Scene m) => ST m () []
game {m} = with ST do
  draw <- initDraw (fst resolution) (snd resolution)
  textureCache <- initCache {r=Texture}
  mapCache <- initCache {r=MapDescriptor}
  emptyContext <- createEmptyContext

  Just map <- get {m} {r=MapDescriptor} mapCache emptyContext "likert" | Nothing => ?noLikert
  scene <- startScene map
  let playerCreation = MkCreation (Just "player")
                                  "disciple"
                                  (0, 20)
                                  []
                                  Nothing
                                  Nothing
                                  Nothing
  create scene playerCreation

  state <- new ()
  camera <- new (0, 0)
  lastms <- new !ticks
  combine state [draw, scene, camera, textureCache, lastms]

  loop state

  [draw, scene, camera, textureCache, lastms] <- split state
  quitDraw draw
  endScene scene
  quitCache {r=Texture} textureCache
  quitCache {r=MapDescriptor} mapCache
  deleteEmptyContext emptyContext
  delete camera; delete lastms
  delete state


main : IO ()
main = run game
