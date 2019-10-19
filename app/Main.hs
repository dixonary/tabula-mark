module Main where

import System.IO
import System.Directory
import Control.Monad
import Data.Functor ((<&>))
import Data.Function ((&))
import Data.Maybe

import Warwick.Config
import Warwick.Tabula hiding (moduleCode)
import Warwick.Tabula.Attachment
import Warwick.Tabula.Payload.Marks

import Data.HashMap.Lazy as Map

import Data.UUID.Types as UUID

import System.Environment
import Shelly

import Data.Text (Text)
import qualified Data.Text as T
default (T.Text)

{-
mark
Assignment UID: <read input>
<make .assignment file with contents>

Loop
  User ID: <read input>
  <download and open submission pdf, cp template.txt uid.txt, vim uid.txt>
  Final mark: <read input>
  <upload uid.txt, upload mark>
-}

type AssignmentMap = HashMap String (Maybe Submission)

moduleCode = "cs130"

tmpDir :: AssignmentID -> String
tmpDir ass = "/tmp/mark/" ++ idAsString ass

mkTmpDir :: AssignmentID -> IO ()
mkTmpDir ass = shelly $ mkdir_p $ toShellyPath $ tmpDir ass


main :: IO ()
main = do
    tabulaConfig <- shelly $ APIConfig
        <$> get_env_text "TABULA_UID"
        <*> get_env_text "TABULA_PASS"

    assignmentId <- getAssignmentId <&> read <&> AssignmentID :: IO AssignmentID
    mkTmpDir assignmentId

    assignmentsRaw <- withAPI Live tabulaConfig $
        listSubmissions moduleCode assignmentId 

    putStrLn "Downloading assignment submissions data..."

    case assignmentsRaw of
        Right TabulaOK{..} -> do
            let assignments = tabulaData
            forever $ mark assignments tabulaConfig assignmentId
        _ -> do
            putStrLn "!! Couldn't find assignment (Is the assignment ID correct?)"
            



mark :: AssignmentMap -> APIConfig -> AssignmentID -> IO ()
mark assignments tabulaConfig assignmentId = do
    mapM_ putStrLn ["","--------------------------------------------------",""]
    
    putStrFl "User code: "

    -- Do a rudimentary check that this is, in fact, a user id
    uid <- getLine

    let submissionM = Map.lookup uid assignments
    case submissionM of
        Nothing -> do
            putStrLn "!! Submission not found. (Is the User ID correct?)"
            return ()
    
        Just Nothing ->
            putStrLn "!! This user has not submitted (yet)."

        Just (Just Submission{..}) -> do

            let
                userSubmissionPath = tmpDir assignmentId ++ "/uid"
                userFeedbackPath   = uid ++ ".txt"

            putStrLn $ "Downloading submission..."

            forM_ submissionAttachments $ \Attachment{..} ->
                    withAPI Live tabulaConfig $ 
                        downloadSubmission 
                            uid 
                            moduleCode
                            assignmentId 
                            submissionID 
                            attachmentFilename 
                            userSubmissionPath

            shelly $ do
                editor <- toShellyPath . T.unpack . fromMaybe "vim" <$> get_env "EDITOR"

                cp "template" $ toShellyPath userFeedbackPath
                cmd "open" $ toShellyPath userSubmissionPath
                runHandles editor
                    [T.pack userFeedbackPath] 
                    [InHandle $ Inherit, OutHandle $ Inherit] 
                    (const $ const $ const $ return ())

            putStrFl "Enter final mark: "
            mark <- read <$> getLine :: IO Int
            feedbackText <- T.pack <$> readFile userFeedbackPath

            putStrLn "Uploading marks..."
            
            let feedback = Marks
                    [ FeedbackItem
                        { fiId       = T.pack uid
                        , fiMark     = Just $ T.pack $ show mark
                        , fiGrade    = Nothing
                        , fiFeedback = Just feedbackText
                        }
                    ]
            
            res <- withAPI Live tabulaConfig 
                    $ postMarks moduleCode assignmentId feedback

            case res of
                Right _ -> putStrLn $ "... Uploaded successfully."
                Left e  -> putStrLn $ "!! Marks not uploaded:\n" ++ show e




-- Either start a new assignment marking, or read the existing assignment ID
-- from a file.s
getAssignmentId :: IO String
getAssignmentId = do
    let assFile = ".assignment"
    exists <- doesFileExist assFile

    if exists
        then do
            ass <- readFile assFile
            putStrLn $ "Assignment found (" ++ ass ++ ")"
            return ass

        else do
            putStrFl "Assignment UID: "
            hFlush stdout
            ass <- getLine

            writeFile assFile ass
            return ass


-- helpers
putStrFl :: String -> IO ()
putStrFl x = putStr x >> hFlush stdout

toShellyPath :: System.IO.FilePath -> Shelly.FilePath
toShellyPath = Shelly.fromText . T.pack 

idAsString :: AssignmentID -> String
idAsString = T.unpack . toText . unAssignmentID