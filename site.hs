--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Char
import           Data.Monoid (mappend)
import           Data.List (intercalate)
import qualified Data.Map as M
import           Hakyll
import           Hakyll.Web.Tags
import           System.FilePath.Posix  (takeBaseName, takeDirectory,
                                         (</>), takeFileName)

--------------------------------------------------------------------------------
main :: IO ()
main = hakyll $ do

       match "assets/js/**" $ do
             route assetsRoute
             compile copyFileCompiler

       match "assets/css/**" $ do
             route assetsRoute
             compile compressCssCompiler

       match "assets/images/**" $ do
             route assetsRoute
             compile copyFileCompiler

       match "assets/fonts/**" $ do
             route assetsRoute
             compile copyFileCompiler

       match (fromList ["404.md", "CNAME"]) $ do
             route idRoute
             compile copyFileCompiler

       tags <- buildTags "posts/**" (fromCapture "tags/*.html")

       let posts = recentFirst =<< loadAll "posts/**"
       let postCtx = dateField "date" "%B %e, %Y" `mappend`
             tagsField "tagsCtx" tags `mappend`
             defaultContext
       let ctxWithPosts title =
             constField "title" title `mappend`
             listField "posts" postCtx posts `mappend`
             defaultContext

       match "posts/**" $ do
             route $ postRoute
             compile $ do
               pandocCompiler
                     >>= loadAndApplyTemplate "templates/with-title.html"   postCtx
                     >>= loadAndApplyTemplate "templates/with-sidebar.html" postCtx
                     >>= loadAndApplyTemplate "templates/default.html"      postCtx
                     >>= relativizeUrls

       match "templates/**" $ compile templateBodyCompiler

       create ["index.html"] $ do
         route idRoute
         let ctx = ctxWithPosts "AceHack"
         compile $ do
           makeItem ""
             >>= loadAndApplyTemplate "templates/with-title.html"   ctx
             >>= loadAndApplyTemplate "templates/index.html"        ctx
             >>= loadAndApplyTemplate "templates/with-sidebar.html" ctx
             >>= loadAndApplyTemplate "templates/default.html"      ctx
             >>= relativizeUrls
             >>= cleanIndexHtmls

       create ["archives.html"] $ do
         route $ cleanRoute True
         let ctx = ctxWithPosts "Archive"
         compile $ do
           makeItem ""
             >>= loadAndApplyTemplate "templates/with-title.html"   ctx
             >>= loadAndApplyTemplate "templates/archive.html"      ctx
             >>= loadAndApplyTemplate "templates/with-sidebar.html" ctx
             >>= loadAndApplyTemplate "templates/default.html"      ctx
             >>= relativizeUrls

       match (fromList ["about.md"])$ do
         route $ cleanRoute True
         let ctx = ctxWithPosts "About"
         compile $ do
           pandocCompiler
             >>= loadAndApplyTemplate "templates/with-title.html"   ctx
             >>= loadAndApplyTemplate "templates/with-sidebar.html" ctx
             >>= loadAndApplyTemplate "templates/default.html"      ctx
             >>= relativizeUrls

       create ["sitemap.xml"] $ do
              route   idRoute
              let ctx = ctxWithPosts "SiteMap"
              compile $ do
                makeItem ""
                 >>= loadAndApplyTemplate "templates/sitemap.xml" ctx
                 >>= cleanIndexHtmls


--------------------------------------------------------------------------------
type Year = String

postsByYear :: Year -> Compiler [Item String]
postsByYear year = do
  posts <- recentFirst =<< loadAll (fromGlob $ "posts/" ++ year ++ "**")
  return posts

buildYears :: MonadMetadata m => Pattern -> m [(Year, Int)]
buildYears pattern = do
    ids <- getMatches pattern
    return . frequency . (map getYear) $ ids
  where
    frequency xs =  M.toList (M.fromListWith (+) [(x, 1) | x <- xs])

getYear :: Identifier -> Year
getYear = takeBaseName . takeDirectory . toFilePath

cleanIndexHtmls :: Item String -> Compiler (Item String)
cleanIndexHtmls = return . fmap (replaceAll pattern replacement)
    where
      pattern = "/index.html"

replacement :: String -> String
replacement = const "/"

pathToPostRoute :: Identifier -> String
pathToPostRoute path =
  year ++ "/" ++ month ++ "/" ++ rest
  where
    year = takeWhile (/= '-') $ fileName
    month = takeWhile (/= '-') . drop 1 . dropWhile (/= '-') $ fileName
    rest = dropWhile (\x -> isDigit x || x == '-') $ fileName
    fileName = drop 1 . dropWhile (/= '/') $ toFilePath path

postRoute :: Routes
postRoute = (customRoute $ pathToPostRoute) `composeRoutes` cleanRoute False

cleanRoute :: Bool -> Routes
cleanRoute isTopLevel =
  customRoute $
  (++ "/index.html") . takeWhile (/= '.') . (adjustPath isTopLevel) . toFilePath
  where
    adjustPath False = id
    adjustPath True = reverse . takeWhile (/= '/') . reverse

assetsRoute :: Routes
assetsRoute = customRoute $ (\x -> x :: String) . drop 7 . toFilePath
