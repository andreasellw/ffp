{-# LANGUAGE BlockArguments        #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}
module Handler.Game where

import           Game.Game
import           Import
import           Text.Julius           (RawJS (..))
import           Yesod.Form.Bootstrap3 (BootstrapFormLayout (..),
                                        renderBootstrap3)

-- Define our data that will be used for creating the form.
data FileForm = FileForm
    { fileInfo        :: FileInfo
    , fileDescription :: Text
    }

-- GET LATEST GAME
getGameR :: Text -> Handler Html
getGameR gameId = do
    -- print $ unpack gameId
    gameStateDBEntity <- runDB $ selectList [GameStateEntityGameId ==. unpack gameId] [Desc GameStateEntityUpdatedAt, LimitTo 1]
    -- print gameStateDBEntity
    let maybeGameStateEntity = getGameStateEntity gameStateDBEntity
    let gameStateEntity = case maybeGameStateEntity of
                  Just entity -> entity -- ERROR maybe here?
                  Nothing -> error "HELP ME!"
    defaultLayout $ do
            let (gameTableId, cellId) = gameIds
            setTitle "Game"
            $(widgetFile "game")

-- MAKE MOVE
putGameR :: Text -> Handler Value
putGameR gameId = do
    timeStamp <- liftIO getCurrentTime
    -- requireCheckJsonBody will parse the request body into the appropriate type, or return a 400 status code if the request JSON is invalid.
    -- (The ToJSON and FromJSON instances are derived in the config/models file).
    moveRequest <- (requireCheckJsonBody :: Handler MoveRequest)
    -- print moveEntity
    state <- runDB $ selectList [GameStateEntityGameId ==. unpack gameId] [Desc GameStateEntityUpdatedAt, LimitTo 1]
    -- print state
    let gameStateEntity = getGameStateEntity state
    let gameState = case gameStateEntity of
              Just entity -> makeMove (gameStateEntityToGameState entity) $ moveEntityToMove MoveEntity {moveEntityAction=moveRequestAction moveRequest, moveEntityCoordX=moveRequestCoordX moveRequest, moveEntityCoordY=moveRequestCoordY moveRequest,moveEntityTimeStamp=timeStamp} -- ERROR maybe here?
              Nothing -> error "HELP ME!"
    let createdAt = case gameStateEntity of
              Just entity -> gameStateEntityCreatedAt entity
              Nothing     -> error "HELP ME!"
    -- print gameState
    insertedGameState <- runDB $ insertEntity $ gameStateToGameStateEntity gameState (unpack gameId) createdAt timeStamp
    -- print $ gameState
    -- -- The YesodAuth instance in Foundation.hs defines the UserId to be the type used for authentication.
    -- maybeCurrentUserId <- maybeAuthId
    -- --let newGameEntity' = newGameEntity { newGameUserId = maybeCurrentUserId }
    -- insertedGameState <- runDB $ insertEntity gameState
    returnJson insertedGameState

-- postGameR :: Handler Value
-- postGameR = do
--     -- requireCheckJsonBody will parse the request body into the appropriate type, or return a 400 status code if the request JSON is invalid.
--     -- (The ToJSON and FromJSON instances are derived in the config/models file).
--     cell <- (requireCheckJsonBody :: Handler Game)
--     print $ cell
--     -- The YesodAuth instance in Foundation.hs defines the UserId to be the type used for authentication.
--     maybeCurrentUserId <- maybeAuthId
--     let cell' = cell { gameUserId = maybeCurrentUserId }
--     insertedCell <- runDB $ insertEntity cell'
--     returnJson insertedCell

getGameStateEntity :: [Entity GameStateEntity] -> Maybe GameStateEntity
getGameStateEntity (x:_) = Just $ entityVal x
getGameStateEntity _     = Nothing

gameIds :: (Text, Text)
gameIds = ("js-gameTableId", "js-cellId")