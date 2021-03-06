module Main where

import "aeson" Data.Aeson (encode)
import "base" Data.Foldable (find)
import "base" Data.Function ((&))
import "data-default-class" Data.Default.Class (Default (def))
import "lens" Control.Lens (Prism', view, preview, element, (^.), (^?))
import "xml-lens" Text.XML.Lens (Element (..), Name (..), Node (..), (^..), (./)
	, attributeIs, root, nodes, name, named, entire, text, _Element, _Content)
import "text" Data.Text (Text, unpack)

import qualified "containers" Data.Map.Lazy as Map (fromList, lookup)
import qualified "xml-conduit" Text.XML as XML (readFile)
import qualified "bytestring" Data.ByteString.Lazy as Lazybytes (writeFile)

import TV.Timeslot (Timeslot (Timeslot), parse_timeslot)
import TV.Program (Program (Program))
import TV.Channel (Channel (Channel))
import TV.Week (Week (Week, monday))

elements :: Element -> [Element]
elements e = (preview _Element) <$> (e ^. nodes) &
	foldr (\x acc -> maybe acc (flip (:) acc) x) []

contents :: Element -> [Text]
contents e = (preview _Content) <$> (e ^. nodes) &
	foldr (\x acc -> maybe acc (flip (:) acc) x) []

extract_day_of_week :: Text -> [Element] -> Maybe Element
extract_day_of_week day = find ((==) (Just day) . Map.lookup "id" . elementAttributes)

extract_channels :: Element -> [Channel]
extract_channels = foldr (\x acc -> maybe acc (flip (:) acc) x) []
	. fmap parse_channel . filter ((==) "div" . view name) . elements

extract_programs :: Element -> [Program]
extract_programs = foldr (\x acc -> maybe acc (flip (:) acc) x) []
	. fmap parse_program . filter ((==) "div" . view name) . elements

parse_channel :: Element -> Maybe Channel
parse_channel e = Channel
	<$> (fmap (mconcat . contents) $ find ((==) "h3" . view name) $ elements e)
	<*> Just (extract_programs e)

parse_week :: [Element] -> Maybe Week
parse_week days = Week
	<$> (extract_channels <$> extract_day_of_week "monday" days)
	<*> (extract_channels <$> extract_day_of_week "tuesday" days)
	<*> (extract_channels <$> extract_day_of_week "wednesday" days)
	<*> (extract_channels <$> extract_day_of_week "thursday" days)
	<*> (extract_channels <$> extract_day_of_week "friday" days)
	<*> (extract_channels <$> extract_day_of_week "saturday" days)
	<*> (extract_channels <$> extract_day_of_week "sunday" days)

parse_program :: Element -> Maybe Program
parse_program e = Program
	<$> items ^? element 1
	<*> (items ^? element 0 >>= parse_timeslot . unpack) where

	items :: [Text]
	items = e ^.. entire >>= contents

main = do
	doc <- XML.readFile def "Temporary/tv.html"
	let days = doc ^.. root ./ named "body" ./ attributeIs "id" "content" ./ attributeIs "class" "day"
	parse_week days & maybe (print "Parsing TV listing is failed")
		(Lazybytes.writeFile "Temporary/result.json" . encode)
