{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StandaloneDeriving #-}
module SpriteMap where
import Enemy ()

import qualified Game.Waddle          as WAD
import Data.Maybe
import qualified  Data.Map.Strict as M

deriving instance Ord WAD.ThingType

thingToSprite :: WAD.ThingType -> WAD.LumpName
thingToSprite t
  = fromMaybe (error "NO THING")
        (thingTypeToInt t >>= \t' -> M.lookup t' thingIdToSprite)

reservedSpriteIds :: [Int]
reservedSpriteIds = [-1, 0, 1, 2, 3, 4, 11, 14]

thingTypeToInt :: WAD.ThingType -> Maybe Int
thingTypeToInt t
  = M.lookup t typeToInt

nonReservedSprites :: [WAD.Thing] -> [WAD.Thing]
nonReservedSprites things
    = [ t
      | t <- things
      , fromJust (thingTypeToInt (WAD.thingType t)) `notElem` reservedSpriteIds
      ]

typeToInt :: M.Map WAD.ThingType Int
typeToInt
    = M.fromList $ map (\i -> (WAD.thingTypeFromNumber i, i)) [0..3006]

thingIdToSprite  :: M.Map Int WAD.LumpName
thingIdToSprite = M.fromList [
  (-1,"ffff"),
  (0,"0000"),
  (1,"PLAY"),
  (2,"PLAY"),
  (3,"PLAY"),
  (4,"PLAY"),
  (11,"----"),
  (14,"----"),
  (3004,"POSS"),
  (84,"SSWV"),
  (9,"SPOS"),
  (65,"CPOS"),
  (3001,"TROO"),
  (3002,"SARG"),
  (58,"SARG"),
  (3006,"SKUL"),
  (3005,"HEAD"),
  (69,"BOS2"),
  (3003,"BOSS"),
  (68,"BSPI"),
  (71,"PAIN"),
  (66,"SKEL"),
  (67,"FATT"),
  (64,"VILE"),
  (7,"SPID"),
  (16,"CYBR"),
  (88,"BBRN"),
  (89,"-"),
  (87,"-"),
  (2005,"CSAW"),
  (2001,"SHOT"),
  (82,"SGN2"),
  (2002,"MGUN"),
  (2003,"LAUN"),
  (2004,"PLAS"),
  (2006,"BFUG"),
  (2007,"CLIP"),
  (2008,"SHEL"),
  (2010,"ROCK"),
  (2047,"CELL"),
  (2048,"AMMO"),
  (2049,"SBOX"),
  (2046,"BROK"),
  (17,"CELP"),
  (8,"BPAK"),
  (2011,"STIM"),
  (2012,"MEDI"),
  (2014,"BON1"),
  (2015,"BON2"),
  (2018,"ARM1"),
  (2019,"ARM2"),
  (83,"MEGA"),
  (2013,"SOUL"),
  (2022,"PINV"),
  (2023,"PSTR"),
  (2024,"PINS"),
  (2025,"SUIT"),
  (2026,"PMAP"),
  (2045,"PVIS"),
  (5,"BKEY"),
  (40,"BSKU"),
  (13,"RKEY"),
  (38,"RSKU"),
  (6,"YKEY"),
  (39,"YSKU"),
  (2035,"BAR1"),
  (72,"KEEN"),
  (48,"ELEC"),
  (30,"COL1"),
  (32,"COL3"),
  (31,"COL2"),
  (36,"COL5"),
  (33,"COL4"),
  (37,"COL6"),
  (47,"SMIT"),
  (43,"TRE1"),
  (54,"TRE2"),
  (2028,"COLU"),
  (85,"TLMP"),
  (86,"TLP2"),
  (34,"CAND"),
  (35,"CBRA"),
  (44,"TBLU"),
  (45,"TGRE"),
  (46,"TRED"),
  (55,"SMBT"),
  (56,"SMGT"),
  (57,"SMRT"),
  (70,"FCAN"),
  (41,"CEYE"),
  (42,"FSKU"),
  (49,"GOR1"),
  (63,"GOR1"),
  (50,"GOR2"),
  (59,"GOR2"),
  (52,"GOR4"),
  (60,"GOR4"),
  (51,"GOR3"),
  (61,"GOR3"),
  (53,"GOR5"),
  (62,"GOR5"),
  (73,"HDB1"),
  (74,"HDB2"),
  (75,"HDB3"),
  (76,"HDB4"),
  (77,"HDB5"),
  (78,"HDB6"),
  (25,"POL1"),
  (26,"POL6"),
  (27,"POL4"),
  (28,"POL2"),
  (29,"POL3"),
  (10,"PLAY"),
  (12,"PLAY"),
  (24,"POL5"),
  (79,"POB1"),
  (80,"POB2"),
  (81,"BRS1"),
  (15,"PLAY"),
  (18,"POSS"),
  (19,"SPOS"),
  (20,"TROO"),
  (21,"SARG"),
  (22,"HEAD"),
  (23,"SKUL")]
