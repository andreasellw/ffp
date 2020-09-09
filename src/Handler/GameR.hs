{-# LANGUAGE BlockArguments        #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}
module Handler.GameR where

import           Game.Game (makeMove)
import           Game.Util
import           Import
import           Marshalling


-- GET GAME VIEW
getGameR :: Text -> Handler Html
getGameR gameIdText = do
    now <- liftIO getCurrentTime
    gameStateDBEntities <- runDB $ selectList [GameStateEntityGameId ==. unpack gameIdText] [Desc GameStateEntityUpdatedAt, LimitTo 1]
    let (gsEntity, gsKey) = getGameStateEntityAndKey gameStateDBEntities
    -- If gameState was Paused, continue game and set lastStartedAt
    let gameStateEntity = case _gameStateEntityStatus gsEntity of "Paused" -> gsEntity {_gameStateEntityStatus = "Ongoing", _gameStateEntityLastStartedAt = now}
                                                                  _        -> gsEntity
    -- Insert updated game back to db                                                             
    _ <- runDB $ repsert gsKey gameStateEntity
                                                 
    defaultLayout $ do
            let (gameTableId, cellId) = gameIds
            aDomId <- newIdent
            setTitle "Game"
            $(widgetFile "game")

-- MAKE MOVE
putGameR :: Text -> Handler Html
putGameR gameIdText = do
    -- requireCheckJsonBody will parse the request body into the appropriate type, or return a 400 status code if the request JSON is invalid.
    -- (The ToJSON and FromJSON instances are derived in the config/models file).
    moveRequest <- (requireCheckJsonBody :: Handler MoveRequest)
    let gameId = unpack gameIdText
    now <- liftIO getCurrentTime

    gameStateDBEntities <- runDB $ selectList [GameStateEntityGameId ==. gameId] [Desc GameStateEntityUpdatedAt, LimitTo 1]
    let (gsEntity, _) = getGameStateEntityAndKey gameStateDBEntities
    let newGameState = makeMove (gameStateEntityToGameState gsEntity) $ moveRequestToMove moveRequest now

    let updatedGameStateEntity = gameStateToGameStateEntity newGameState

    _ <- runDB $ upsertBy (UniqueGameStateEntity gameId) updatedGameStateEntity [GameStateEntityMoves =. _gameStateEntityMoves updatedGameStateEntity,
                                                                                 GameStateEntityBoard =. _gameStateEntityBoard updatedGameStateEntity,
                                                                                 GameStateEntityStatus =. _gameStateEntityStatus updatedGameStateEntity,
                                                                                 GameStateEntityTimeElapsed =. _gameStateEntityTimeElapsed updatedGameStateEntity,
                                                                                 GameStateEntityUpdatedAt =. now]
    
    let gameStateEntity = updatedGameStateEntity
    defaultLayout $ do
            let (gameTableId, cellId) = gameIds
            aDomId <- newIdent
            setTitle "Game"
            $(widgetFile "game")

gameIds :: (Text, Text)
gameIds = ("js-gameTableId", "js-cellId")

-- isFlagged Bool
-- isRevealed Bool
-- hasBomb Bool
-- neighboringBombs Int
getCellTile :: Bool -> Bool -> Bool -> Int -> String
getCellTile False True False 0 = "/static/assets/type0.svg"
getCellTile False True False 1 = "/static/assets/type1.svg"
getCellTile False True False 2 = "/static/assets/type2.svg"
getCellTile False True False 3 = "/static/assets/type3.svg"
getCellTile False True False 4 = "/static/assets/type4.svg"
getCellTile False True False 5 = "/static/assets/type5.svg"
getCellTile False True False 6 = "/static/assets/type6.svg"
getCellTile False True False 7 = "/static/assets/type7.svg"
getCellTile False True False 8 = "/static/assets/type8.svg"
getCellTile True True True _   = "/static/assets/mine.svg"
getCellTile True True False _  = "/static/assets/mine_wrong.svg"
getCellTile False True True _  = "/static/assets/mine_red.svg"
getCellTile True False _ _     = "/static/assets/flag.svg"
getCellTile _ False _ _        = "/static/assets/closed.svg"
getCellTile _ _ _ _            = undefined

getCellTileWon :: Bool -> Bool -> Bool -> Int -> String
getCellTileWon False _ False 0    = "/static/assets/type0.svg"
getCellTileWon False _ False 1    = "/static/assets/type1.svg"
getCellTileWon False _ False 2    = "/static/assets/type2.svg"
getCellTileWon False _ False 3    = "/static/assets/type3.svg"
getCellTileWon False _ False 4    = "/static/assets/type4.svg"
getCellTileWon False _ False 5    = "/static/assets/type5.svg"
getCellTileWon False _ False 6    = "/static/assets/type6.svg"
getCellTileWon False _ False 7    = "/static/assets/type7.svg"
getCellTileWon False _ False 8    = "/static/assets/type8.svg"
getCellTileWon True _ True _      = "/static/assets/flag.svg"
getCellTileWon _ _ _ _            = "/static/assets/closed.svg"

getCellTileLost :: Bool -> Bool -> Bool -> Int -> String
getCellTileLost False True False 0 = "/static/assets/type0.svg"
getCellTileLost False True False 1 = "/static/assets/type1.svg"
getCellTileLost False True False 2 = "/static/assets/type2.svg"
getCellTileLost False True False 3 = "/static/assets/type3.svg"
getCellTileLost False True False 4 = "/static/assets/type4.svg"
getCellTileLost False True False 5 = "/static/assets/type5.svg"
getCellTileLost False True False 6 = "/static/assets/type6.svg"
getCellTileLost False True False 7 = "/static/assets/type7.svg"
getCellTileLost False True False 8 = "/static/assets/type8.svg"
getCellTileLost True False False _ = "/static/assets/mine_wrong.svg"
getCellTileLost False True True _  = "/static/assets/mine_red.svg"
getCellTileLost _ False True _     = "/static/assets/mine.svg"
getCellTileLost _ _ _ _            = "/static/assets/closed.svg"

getRemainingFlags :: [Row] -> Int -> Int
getRemainingFlags rows bombCount = bombCount - sum (concatMap mapCells rows) 
                                   where mapCells row = map cellToInt $ _rowCells row 
                                                        where cellToInt cell = fromEnum $ _cellEntityIsFlagged cell


getTimeElapsed :: UTCTime -> Int -> UTCTime -> String -> Int
getTimeElapsed lastStartedAt timeElapsed now status = case status of
                                                      "Won"   -> timeElapsed
                                                      "Lost"  -> timeElapsed
                                                      _       -> calculateTimeElapsed lastStartedAt timeElapsed now
