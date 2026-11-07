--------------------------------------------------------------------------------------------------------
--
-- Services/PvP.lua
-- Normalizes honor, rank and arena data for the PvP displays.
--
----------------------


--------------------------------------------------------------------------------------------------------
--                                      Variables And Constants                                       --
--------------------------------------------------------------------------------------------------------

local _, ns = ...
if ns.blocked then
    return
end
local C, P = ns.Compat, {}
ns.PvP = P
local L = ns.L


--------------------------------------------------------------------------------------------------------
--                                          Value Validation                                          --
--------------------------------------------------------------------------------------------------------

-- Accept a nonnegative finite PvP counter.
function P.Count(value)
    if C.IsNumber(value) and value >= 0 and value < math.huge and value % 1 == 0 then
        return value
    end
end


--------------------------------------------------------------------------------------------------------
--                                             Honor Rank                                             --
--------------------------------------------------------------------------------------------------------

-- Calculate rank progress only from supported rank data.
function P.RankProgress(points, threshold)
    points, threshold = P.Count(points), P.Count(threshold)
    if points and threshold and threshold > 0 and points <= threshold then
        return points / threshold * 100
    end
end


--------------------------------------------------------------------------------------------------------
--                                           Rated Records                                            --
--------------------------------------------------------------------------------------------------------

-- Normalize played games, wins and losses.
function P.Record(played, won, rounds)
    played, won = P.Count(played), P.Count(won)
    if played and won and won <= played then
        return { played = played, won = won, lost = played - won, rounds = rounds or nil }
    end
end

-- Format the available win and loss counts.
function P.FormatWins(won)
    return C.FormatNumber(won) .. " " .. L["Wins short"]
end

-- Format a rated-PvP record with its match count.
function P.FormatRecord(record)
    return P.FormatWins(record.won)
        .. " / "
        .. C.FormatNumber(record.lost)
        .. " "
        .. L["Losses short"]
        .. " ("
        .. C.FormatNumber(record.played)
        .. " "
        .. L[record.rounds and "rounds" or "games"]
        .. ")"
end

-- Collect return values from an optional PvP API.
local function Values(...)
    return { n = select("#", ...), ... }
end
local rated = { arena2 = true, arena3 = true, arena5 = true, rbg = true, shuffle = true, blitz = true }


--------------------------------------------------------------------------------------------------------
--                                        Client Capabilities                                         --
--------------------------------------------------------------------------------------------------------

-- Check whether a PvP field belongs to this client.
function P.Allows(key)
    if key == "honorLevel" then
        return C.isRetail
    end
    if key == "lifetimeHK" then
        return true
    end
    if key == "arena2" or key == "arena3" or key == "rbg" then
        return C.isRetail or C.isForever or C.isMists
    end
    if key == "arena5" then
        return C.isMists
    end
    if key == "shuffle" or key == "blitz" then
        return C.profile.soloRated
    end
    return C.isForever
        and (
            key == "foreverRank"
            or key == "rankProgress"
            or key == "honorCurrent"
            or key == "honorNextLevel"
            or key == "todayHK"
            or key == "weeklyRankCap"
            or key == "weeklyRankCapIncrease"
        )
end

-- Keep only PvP fields supported by this client.
function P.Filter(data)
    for _, key in ipairs({
        "honorLevel",
        "lifetimeHK",
        "arena2",
        "arena3",
        "arena5",
        "rbg",
        "shuffle",
        "blitz",
        "foreverRank",
        "rankProgress",
        "honorCurrent",
        "honorNextLevel",
        "todayHK",
        "weeklyRankCap",
        "weeklyRankCapIncrease",
        "todayHonor",
        "yesterdayHK",
        "yesterdayHonor",
        "rank",
        "rankName",
    }) do
        if not P.Allows(key) then
            data[key] = nil
        elseif key == "rankProgress" then
            local value = data[key]
            if not C.IsNumber(value) or not (value >= 0 and value <= 100) then
                data[key] = nil
            end
        else
            data[key] = P.Count(data[key])
        end
    end
    if data.foreverRank and data.foreverRank > 14 then
        data.foreverRank = nil
    end
    for _, group in ipairs({ "records", "weekly", "wins" }) do
        if not C.IsTable(data[group]) then
            data[group] = {}
        end
        for key, value in pairs(data[group]) do
            if not rated[key] or not P.Allows(key) then
                data[group][key] = nil
            elseif group == "wins" then
                data[group][key] = key == "rbg" and P.Count(value) or nil
            elseif group == "weekly" and not key:match("^arena") then
                data[group][key] = nil
            else
                data[group][key] = C.IsTable(value) and P.Record(value.played, value.won, key == "shuffle")
                    or nil
            end
        end
    end
    return data
end


--------------------------------------------------------------------------------------------------------
--                                             Honor Data                                             --
--------------------------------------------------------------------------------------------------------

-- Read the available lifetime and session honor data.
function P.Honor(unit, isSelf)
    local data = {}
    if isSelf then
        local hk, dk = C.Try(GetPVPSessionStats)
        data.todayHK = P.Count(hk)
        data.todayDK = P.Count(dk)
        local yesterday, _, honor = C.Try(GetPVPYesterdayStats)
        data.yesterdayHK = P.Count(yesterday)
        data.yesterdayHonor = P.Count(honor)
        local lifetime, dishonorable, rank = C.Try(GetPVPLifetimeStats)
        data.lifetimeHK = P.Count(lifetime)
        data.lifetimeDK = P.Count(dishonorable)
        data.lifetimeRank = P.Count(rank)
        local week, weekHonor = C.Try(GetPVPThisWeekStats)
        data.thisWeekHK = P.Count(week)
        data.thisWeekHonor = P.Count(weekHonor)
        local last, _, lastHonor, standing = C.Try(GetPVPLastWeekStats)
        data.lastWeekHK = P.Count(last)
        data.lastWeekHonor = P.Count(lastHonor)
        data.lastWeekStanding = P.Count(standing)
        if C.isForever then
            -- Blizzard's PVPRankFrame uses the PvP rank faction, not UnitHonor.
            local info = C.Try(C_MajorFactions and C_MajorFactions.GetMajorFactionProgressionInfo, 2800)
            if C.IsTable(info) then
                data.foreverRank = P.Count(info.renownLevel)
                data.honorCurrent, data.honorNextLevel =
                    P.Count(info.renownReputationEarned), P.Count(info.renownLevelThreshold)
                data.rankProgress = P.RankProgress(data.honorCurrent, data.honorNextLevel)
                -- Use the same progression levels as Blizzard's own PvP detail pane.
                local currentLevel = P.Count(info.currentWeekProgressiveMaxLevel)
                local previousLevel = P.Count(info.previousWeekProgressiveMaxLevel)
                if currentLevel then
                    data.weeklyRankCap = P.Count(C.Try(C_MajorFactions.GetTotalReputationForRenownLevel, 2800, currentLevel))
                end
                if data.weeklyRankCap and previousLevel then
                    local previousCap = P.Count(C.Try(C_MajorFactions.GetTotalReputationForRenownLevel, 2800, previousLevel))
                    if previousCap and data.weeklyRankCap >= previousCap then
                        data.weeklyRankCapIncrease = data.weeklyRankCap - previousCap
                    end
                end
                if
                    data.foreverRank
                    and data.foreverRank > 0
                    and data.foreverRank == P.Count(info.maxLevel)
                    and data.honorCurrent
                    and data.honorNextLevel == 0
                then
                    data.rankProgress = 100
                end
            end
        end
    else
        local v = Values(C.Try(GetInspectHonorData))
        if v.n >= 10 then
            data.todayHK, data.todayDK = P.Count(v[1]), P.Count(v[2])
            data.yesterdayHK, data.yesterdayHonor = P.Count(v[3]), P.Count(v[4])
            data.thisWeekHK, data.thisWeekHonor = P.Count(v[5]), P.Count(v[6])
            data.lastWeekHK, data.lastWeekHonor, data.lastWeekStanding =
                P.Count(v[7]), P.Count(v[8]), P.Count(v[9])
            data.lifetimeHK, data.lifetimeDK, data.lifetimeRank =
                P.Count(v[10]), P.Count(v[11]), P.Count(v[12])
        elseif v.n >= 5 and v.n <= 9 then
            data.todayHK, data.todayHonor = P.Count(v[1]), P.Count(v[2])
            data.yesterdayHK, data.yesterdayHonor = P.Count(v[3]), P.Count(v[4])
            data.lifetimeHK, data.lifetimeRank, data.honorLevel = P.Count(v[5]), P.Count(v[6]), P.Count(v[7])
            if C.isForever and v.n >= 9 then
                data.foreverRank = P.Count(v[7])
                data.honorCurrent, data.honorNextLevel = P.Count(v[8]), P.Count(v[9])
                data.rankProgress = P.RankProgress(data.honorCurrent, data.honorNextLevel)
            end
        end
    end
    if C.hasLegacyHonor then
        data.currentRank = P.Count(C.Try(UnitPVPRank, unit))
        local api
        if isSelf then
            api = GetPVPRankProgress
        else
            api = GetInspectPVPRankProgress
        end
        local progress = C.Number(C.Try(api))
        if progress and progress >= 0 and progress <= 1 then
            data.rankProgress = progress * 100
        end
    end
    return data
end


--------------------------------------------------------------------------------------------------------
--                                             Arena Data                                             --
--------------------------------------------------------------------------------------------------------

-- Read the rated brackets supported by this client.
function P.Arena(index, isSelf)
    local name, size, rating, played, won, personal, weeklyPlayed, weeklyWon
    if isSelf and C.isTBC then
        local _teamPlayed, _teamWon, _playerPlayed, _seasonPlayed, _rank
        name, size, rating, _teamPlayed, _teamWon, played, won, _playerPlayed, _seasonPlayed, _rank, personal =
            C.Try(GetArenaTeam, index)
    elseif not isSelf and C.isTBC then
        local playerPlayed
        if C.Try(GetCurrentArenaSeasonUsesTeams) ~= false then
            name, size, rating, played, won, playerPlayed, personal = C.Try(GetInspectArenaTeamData, index)
        end
    end
    if not isSelf and not P.Count(rating) and not C.Text(name) then
        local _teamID
        rating, played, won, weeklyPlayed, weeklyWon, _teamID, size = C.Try(GetInspectArenaData, index)
    end
    if not P.Count(rating) and not P.Record(played, won) then
        return
    end
    size = (size == 2 or size == 3 or size == 5) and size or C.profile.arenaBrackets[index]
    if not size then
        return
    end
    return {
        name = C.Text(name),
        size = size,
        rating = P.Count(rating),
        personal = P.Count(personal),
        record = P.Record(played, won),
        weekly = P.Record(weeklyPlayed, weeklyWon),
    }
end
