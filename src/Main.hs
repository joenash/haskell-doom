{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE ImpredicativeTypes #-}
module Main where
import           Control.Monad
import           Control.Monad.Reader
import           Data.CaseInsensitive hiding (map)
import           Data.Foldable
import           Data.IORef
import           Data.List hiding (map)
import           Data.Maybe
import           Data.Vector.V2
import           Enemy
import           Foreign
import           Game
import           Level.Sector
import           Graphics.GL.Core33
import           Graphics.GLUtils
import           Graphics.Shader
import           Graphics.Binding
import           Graphics.Program
import           Graphics.UI.GLFW
import           Linear
import           Sky
import           Sprite
import           TextureLoader
import           Types
import           Data.Var
import           Window
import           Render
import Graphics.Triangulation.Delaunay
import qualified Data.Map as M
import qualified Game.Waddle          as WAD


width :: Int
height :: Int
(width, height) = (1280, 1024)

type KeyMap = [(Key, Game ())]

twoSidedLineDef :: WAD.LineDef -> Bool
twoSidedLineDef WAD.LineDef{..}
    = isJust lineDefLeftSideDef

main :: IO ()
main = do
    mainLoop <- initGL "E1M1" width height
    wad@WAD.Wad{..} <- WAD.load "doom.wad"
    let level@WAD.Level{..} = head $ toList wadLevels
        levelEnemies  = [mkEnemy t | t <- levelThings, DEnemy _ <- [classifyThingType (WAD.thingType t)]]
        posThing = head $
            filter (\t -> WAD.thingType t == WAD.Player1StartPos) levelThings
        posX = fromIntegral (WAD.thingX posThing) / scale
        posY = fromIntegral (WAD.thingY posThing) / scale
        sectors = extractSectors level

    let projTrans = perspective (0.75 :: GLfloat)
                                (fromIntegral width /
                                    fromIntegral height)
                                1
                                400

    let textToVert = textToVertexData sectors
        dat = concatMap snd . M.toList $ textToVert
        sideDefCount = length dat
        elementBufferData
            = concat $ take sideDefCount $
                iterate (map (+4)) ([0,1,2] ++ [2,1,3])

    elementBufferId <- withNewPtr (glGenBuffers 1)
    glBindBuffer GL_ELEMENT_ARRAY_BUFFER elementBufferId
    withArrayLen elementBufferData $ \len elems ->
        glBufferData GL_ELEMENT_ARRAY_BUFFER
                     (fromIntegral $ len * sizeOf (0 :: GLuint))
                     (elems :: Ptr GLuint)
                     GL_STATIC_DRAW

    program@(Program progId) <- mkProgram wallVert textureFrag

    FragShaderLocation progId "outColor" $= FragDiffuseColor
    Uniform program proj $= projTrans

    levelRData <- forM (M.toList textToVert) $ \(texName, verts) -> do
        vertexBufferId <- withNewPtr (glGenBuffers 1)
        glBindBuffer GL_ARRAY_BUFFER vertexBufferId

        texId <- getTextureId wad texName

        vertexArrayId <- withNewPtr (glGenVertexArrays 1)
        glBindVertexArray vertexArrayId

        bindVertexData program verts

        return RenderData {
                  rdVbo  = vertexBufferId
                , rdEbo  = elementBufferId
                , rdTex  = texId
                , rdProg = program
                , rdVao  = vertexArrayId
                , rdExtra = 0
            }

    --vertexBufferId <- withNewPtr (glGenBuffers 1)
    --glBindBuffer GL_ARRAY_BUFFER vertexBufferId

    --spriteProgram@(Program spriteProgId) <- mkProgram spriteVert spriteFrag

    -- floor
    let floorVertexBufferData
            = concatMap (\Sector{..} ->
                --let -- !xs = traceShowId $ map wallPoints sectorWalls
                --    -- !ys = traceShowId $ triangulation ts
                --    -- !asd = error $ show $ map wallPoints (chainWalls sectorWalls)
                --    ts = triangulation $ nub . concat $ map wallPoints (chainWalls sectorWalls)
                let ts = triangulate' $ nub . concat $ map wallPoints sectorWalls
                 in map (\(V2 x y) ->
                                V3 x sectorFloor y
                    ) ts ++
                    map (\(V2 x y) ->
                                V3 x sectorCeiling y
                    ) ts
              ) sectors
        triangulate' points
            = map vector2Tov2 . concatMap (\(a, b, c) -> [a, b, c])
                $ triangulate (map v2ToVector2 points)
        v2ToVector2 (V2 a b) = Vector2 (realToFrac a) (realToFrac b)
        wallPoints Wall{..} = [wallStart, wallEnd]
        findItem f [] = error "findItem: item not found"
        findItem f (x : xs)
            | f x = (x, xs)
            | otherwise = let (y, ys) = findItem f xs in (y, x : ys)
        chainWalls [] = []
        chainWalls [w] = [w]
        chainWalls (w : ws)
            = let (w', ws') = findItem (\wall -> wallEnd wall == wallStart w) ws
               in w : chainWalls (w' : ws')
               --in case w' of
               --     [found] -> w : chainWalls (found : ws')
               --     []      -> []
        vector2Tov2 (Vector2 a b) = V2 (realToFrac a) (realToFrac b)

    floorVertexBufferId <- withNewPtr (glGenBuffers 1)
    glBindBuffer GL_ARRAY_BUFFER floorVertexBufferId

    floorVertexArrayId <- withNewPtr (glGenVertexArrays 1)
    glBindVertexArray floorVertexArrayId

    floorProgram@(Program floorProgId) <- mkProgram floorVert floorFrag

    FragShaderLocation floorProgId "outColor" $= FragDiffuseColor
    Uniform floorProgram proj $= projTrans

    bindVertexData floorProgram floorVertexBufferData

    glEnable GL_DEPTH_TEST
    glEnable GL_BLEND
    glBlendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA

    let playerPos = V3 posX 1.6 posY

    --texId <- getTextureId wad
    --let levelData = RenderData { rdVbo  = vertexBufferId
    --                           , rdEbo  = elementBufferId
    --                           , rdTex  = texId
    --                           , rdProg = program
    --                           , rdVao  = vertexArrayId
    --                           }
    let floorRData = RenderData { rdVbo  = floorVertexBufferId
                               , rdEbo  = 0
                               , rdTex  = 0
                               , rdProg = floorProgram
                               , rdVao  = floorVertexArrayId
                               , rdExtra = 0
                               }

    spriteProg <- mkProgram spriteVert textureFrag
    Uniform spriteProg proj $= projTrans
    sprites <- createLevelThings wad spriteProg (WAD.levelThings level)
    let palette' = loadPalettes wad
    initState <- GameState <$> return program
                           <*> return sideDefCount
                           <*> pure levelRData
                           <*> pure floorRData
                           <*> pure sprites
                           <*> newIORef undefined -- TODO: current sector
                           <*> newIORef 0
                           <*> newIORef playerPos
                           <*> newIORef levelEnemies
                           <*> pure (loadPalettes wad)
                           <*> fillSkyTextureData wad
                           <*> pistolWeapon wad palette'
                           <*> newIORef 0
                           <*> newIORef 0
    mainLoop (\w -> runGame (loop w (setMapping w)) initState)

pistolWeapon :: WAD.Wad -> ColorPalette -> IO RenderData
pistolWeapon wad palette = do
    wepProgram <- mkProgram staticVert textureFrag

    vaoId <- withNewPtr (glGenVertexArrays 1)
    glBindVertexArray vaoId

    vboId <- withNewPtr (glGenBuffers 1)
    glBindBuffer GL_ARRAY_BUFFER vboId

    let vbo = [ (V3 (-0.2) (-0.1) 0.0, V2 0.0 0.0)
              , (V3  0.2   (-0.1) 0.0, V2 1.0 0.0)
              , (V3 (-0.2) (-0.7) 0.0, V2 0.0 1.0)
              , (V3  0.2   (-0.7) 0.0, V2 1.0 1.0)
              ]
        ebo = [0, 1, 2,
               2, 1, 3]

    bindVertexData wepProgram vbo

    eboId <- withNewPtr (glGenBuffers 1)
    glBindBuffer GL_ELEMENT_ARRAY_BUFFER eboId
    withArrayLen ebo $ \len vertices ->
      glBufferData GL_ELEMENT_ARRAY_BUFFER
                    (fromIntegral $ len * sizeOf (0 :: GLuint))
                    (vertices :: Ptr GLuint)
                    GL_STATIC_DRAW

--still
    let wepSprite = fromMaybe (error "wep not found")
          (M.lookup (mk "PISGA0") (WAD.wadSprites wad))
    let (tW, tH) = (fromIntegral $ WAD.pictureWidth $ WAD.spritePicture wepSprite,
                    fromIntegral $ WAD.pictureHeight $ WAD.spritePicture wepSprite)
    txt <- loadSpriteColor wepSprite palette
    stillTexId <- withNewPtr (glGenTextures 1)
    glBindTexture GL_TEXTURE_2D stillTexId

    glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S (fromIntegral GL_REPEAT)
    glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T (fromIntegral GL_REPEAT)
    glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER (fromIntegral GL_NEAREST)
    glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER (fromIntegral GL_NEAREST)

    withArray txt $
      glTexImage2D GL_TEXTURE_2D 0 (fromIntegral GL_RGBA) tW tH 0 GL_RGBA GL_FLOAT

--firing
    let fwepSprite = fromMaybe (error "fwep not found")
          (M.lookup (mk "PISFA0") (WAD.wadSprites wad))
    let (fW, fH) = (fromIntegral $ WAD.pictureWidth $ WAD.spritePicture fwepSprite,
                    fromIntegral $ WAD.pictureHeight $ WAD.spritePicture fwepSprite)
    ftxt <- loadSpriteColor fwepSprite palette
    firingTexId <- withNewPtr (glGenTextures 1)
    glBindTexture GL_TEXTURE_2D firingTexId

    glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S (fromIntegral GL_REPEAT)
    glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T (fromIntegral GL_REPEAT)
    glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER (fromIntegral GL_NEAREST)
    glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER (fromIntegral GL_NEAREST)

    withArray ftxt $
      glTexImage2D GL_TEXTURE_2D 0 (fromIntegral GL_RGBA) fW fH 0 GL_RGBA GL_FLOAT

    return  RenderData { rdVbo = vboId,
                         rdEbo = eboId,
                         rdTex = stillTexId,
                         rdExtra = firingTexId,
                         rdVao = vaoId,
                         rdProg = wepProgram}

getTextureId :: WAD.Wad -> WAD.LumpName -> IO GLuint
getTextureId wad name = do
    (tW, tH, txt) <- loadTexture wad name
    texId <- withNewPtr (glGenTextures 1)
    glBindTexture GL_TEXTURE_2D texId

    glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S (fromIntegral GL_REPEAT)
    glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T (fromIntegral GL_REPEAT)
    glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER (fromIntegral GL_NEAREST)
    glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER (fromIntegral GL_NEAREST)
    withArray txt $
      glTexImage2D GL_TEXTURE_2D 0 (fromIntegral GL_RGBA) tW tH 0 GL_RGBA GL_FLOAT
    return texId

loop :: Window -> KeyMap -> Game ()
loop w mapping = do
    -- TODO: this is not very nice...
    ticks += 1
    rot' <- get rot
    (V3 px pz py) <- get player
    let ax     = axisAngle (V3 0 1 0) rot'
        modelM = mkTransformationMat identity (V3 px (-pz) (-py))
        lookM  = mkTransformation ax (V3 0 0 0)
        (V4 x1 y1 z1 _)  = lookM !* V4 0 0 1 1
        initV = V3 x1 y1 z1

    gameLogic
    updateView initV modelM
    keyEvents w mapping



updateView :: V3 GLfloat -> M44 GLfloat -> Game ()
updateView initV modelM = do
    -- TODO: most of this stuff shouldn't be set on each update
    glEnable GL_CULL_FACE
    glFrontFace GL_CW
    glCullFace GL_BACK
    glClearColor 0 0 0 1
    glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S (fromIntegral GL_REPEAT)
    glClear (GL_COLOR_BUFFER_BIT .|. GL_DEPTH_BUFFER_BIT)
    prog'@(Program progId) <- asks prog
    glUseProgram progId

    Uniform prog' model $= modelM

    let viewTrans = lookAt (V3 0  0  0)
                           initV
                           (V3 0  1  0) :: M44 GLfloat

    Uniform prog' view $= viewTrans

    -- render the sky
    glDepthMask (fromBool False)
    sky' <- asks sky
    bindRenderData sky'
    glDrawElements GL_TRIANGLES 6 GL_UNSIGNED_INT nullPtr
    glDepthMask (fromBool True)

    --glDrawArrays GL_LINES 0 (fromIntegral ldefc * 4)
    --glPolygonMode GL_FRONT_AND_BACK GL_LINE
    sdefc   <- asks sideDefs
    levelRd' <- asks levelRd

    forM_ levelRd' $ \level -> do
      bindRenderData level
      glBindVertexArray (rdVao level)
      glDrawElements GL_TRIANGLES (fromIntegral sdefc * 6) GL_UNSIGNED_INT nullPtr

    floorRd'@RenderData{rdProg} <- asks floorRd
    bindRenderData floorRd'
    --glPolygonMode GL_FRONT_AND_BACK GL_LINE
    glLineWidth 1
    glDrawArrays GL_TRIANGLES 0 50000 -- TODO: need actual number
    glPolygonMode GL_FRONT_AND_BACK GL_FILL

    Uniform rdProg model $= modelM
    Uniform rdProg view  $= viewTrans

    -- TODO: can be optimized to only bind program once...
    sprites' <- asks sprites
    forM_ sprites' $ \Sprite{..} -> do
      RenderData{rdProg} <- return spriteRenderData
      Uniform rdProg model $= modelM
      Uniform rdProg view  $= viewTrans
      bindRenderData spriteRenderData
      glDrawElements GL_TRIANGLES 6 GL_UNSIGNED_INT nullPtr

    -- render wep
    weapon <- asks pWeapon
    bindRenderData weapon
    ticks' <- asks ticks
    lastShot' <- asks lastShot
    ticks'' <- liftIO $ readIORef ticks'
    lastShot'' <- liftIO $ readIORef lastShot'
    when (ticks'' - lastShot'' <= 25) $
      glBindTexture GL_TEXTURE_2D (rdExtra weapon)
    glDrawElements GL_TRIANGLES 6 GL_UNSIGNED_INT nullPtr

    -- this is a huge mess
    --

extendToV4 :: V3 GLfloat -> V4 GLfloat
extendToV4 (V3 x z y) = V4 x z y 1

multAndProject :: M44 GLfloat -> V3 GLfloat -> V3 GLfloat
multAndProject m v =
  let (V4 x y z _) = m !* extendToV4 v
  in V3 x y z

applyShot :: Game ()
applyShot = return ()

-- TODO: no need to recalculate every time, only when rotating
moveVector :: Game (V3 GLfloat)
moveVector = do
    rot' <- get rot
    let ax     = axisAngle (V3 0 1 0) rot'
        lookM  = mkTransformation ax (V3 0 0 0)
        (V4 x1 y1 z1 _)  = lookM !* V4 0 0 1 1
        move  = V3 (-x1) y1 z1
    return move

keyEvents :: Window -> KeyMap -> Game ()
keyEvents w mapping
    = forM_ mapping $ \(key, action) -> do
        k <- liftIO $ getKey w key
        when (k == KeyState'Pressed) action

setMapping :: Window -> KeyMap
setMapping w
    = [ (Key'Space,  shoot)
      , (Key'W,      moveForward)
      , (Key'S,      moveBackwards)
      , (Key'D,      turnRight)
      , (Key'A,      turnLeft)
      , (Key'Up,     moveUp)
      , (Key'Down,   moveDown)
      , (Key'Left,   moveLeft)
      , (Key'Right,  moveRight)
      , (Key'Escape, quit w)
      ]

-- Actions
quit :: Window -> Game ()
quit w = liftIO $ setWindowShouldClose w True

moveBy :: V3 GLfloat -> Game ()
moveBy by = do
    let moveM = mkTransformationMat identity by
    player $~ multAndProject moveM

shoot :: Game ()
shoot = do
    ticks' <- get ticks
    lastShot $= ticks'
    applyShot

moveLeft :: Game ()
moveLeft = do
    (V3 v1 v2 v3) <- moveVector
    moveBy (V3 (-v3) v2 v1)

moveRight :: Game ()
moveRight = do
    (V3 v1 v2 v3) <- moveVector
    moveBy (V3 v3 v2 (-v1))

moveDown :: Game ()
moveDown
    = moveBy (V3 0 (-0.2) 0)

moveUp :: Game ()
moveUp
    = moveBy (V3 0 0.2 0)

moveForward :: Game ()
moveForward
    = join $ moveBy <$> moveVector

moveBackwards :: Game ()
moveBackwards
    = join $ moveBy . negate <$> moveVector

turnLeft :: Game ()
turnLeft = rot += 0.05

turnRight :: Game ()
turnRight = rot -= 0.05
