local abs, max, min, sqrt, ceil, floor = math.abs, math.max, math.min, math.sqrt, math.ceil, math.floor
local deg, asin, sin, rad = math.deg, math.asin, math.sin, math.rad
local tinsert, tremove = table.insert, table.remove
local costatus, coresume, coyield, cocreate = coroutine.status, coroutine.resume, coroutine.yield, coroutine.create

if not Pathfinder then
	require "PathfinderAsm"
end
Pathfinder = Pathfinder or {}
Pathfinder.DEBUG = Pathfinder.DEBUG or {}

local AllowedDirections = {
{X =  0, 	Y =  1,		Z = 0},
{X = -1, 	Y =  1, 	Z = 0},
{X = -1, 	Y =  0,		Z = 0},
{X = -1, 	Y = -1,		Z = 0},
{X =  0, 	Y = -1,		Z = 0},
{X =  1, 	Y = -1,		Z = 0},
{X =  1, 	Y =  0,		Z = 0},
{X =  1, 	Y =  1,		Z = 0}
}

local TickEndTime = 0 -- end time for coroutines in current tick.
local MAXTracingPrecision, MINTracingPrecision = 1500, 100 -- more = faster tracing, less = accurate result
local HaveMapData = false
local MapFloors, MapAreas, NeighboursWays = {}, {}, {}
local TimerPeriod = ceil(const.Minute/4)
local MonsterWays = {}
local MonStuck = {}
Pathfinder.MonsterWays = MonsterWays

--------------------------------------------------
--					Base functions				--
--------------------------------------------------

function ScalarMul(V1, V2)
	return V1.X*V2.X + V1.Y*V2.Y + V1.Z*V2.Z
end

function VectorModule(V)
	return math.sqrt(V.X^2 + V.Y^2 + V.Z^2)
end

function VectorMul(V1, V2)
	return {X = V1.Y*V2.Z - V1.Z*V2.Y, Y = V1.Z*V2.X - V1.X*V2.Z, Z = V1.X*V2.Y - V1.Y*V2.X}
end

function GetAngleVec(V1, V2)
	return math.acos(ScalarMul(V1, V2)/(VectorModule(V1)*VectorModule(V2)))
end

function MakeVec3D(FromV, ToV)
	return {X = ToV.X - FromV.X, Y = ToV.Y - FromV.Y, Z = ToV.Z - FromV.Z}
end

function PlaneDefVector(V1, V2, V3) -- points of plane
	local a, b, c
	a = MakeVec3D(V1, V2)
	b = MakeVec3D(V1, V3)
	c = VectorMul(a, b)
	return c
end

function PlaneDefiners(V1, V2, V3)
	local A, B, C, D

	-- x - V1.X	V2.X - V1.X	V3.X - V1.X
	-- y - V1.Y	V2.Y - V1.Y	V3.Y - V1.Y
	-- z - V1.Z	V2.Z - V1.Z	V3.Z - V1.Z

	--(x - V1.X)*((V2.Y - V1.Y)*(V3.Z - V1.Z) - (V2.Z - V1.Z)*(V3.Y - V1.Y)) ...

	local VV = PlaneDefVector(V1, V2, V3)
	-- (x - V1.X)*VV.X - (y - V1.Y)*VV.Y + (z - V1.Z)*VV.Z = 0
	-- - V1.X*VV.X + V1.Y*VV.Y - V1.Z*VV.Z

	A = VV.X
	B = VV.Y
	C = VV.Z
	D = - V1.X*VV.X - V1.Y*VV.Y - V1.Z*VV.Z

	return {X = A, Y = B, Z = C, D = D}
end

function PlaneLineIntersection(PlaneV, lV0, lV)
	-- x = lv.X * t + lV0.X -- (x - lv0.X)/lv.X = t
	-- y = lv.Y * t + lV0.Y
	-- z = lv.Z * t + lV0.Z
	-- 0 = PlaneV.X*x + PlaneV.Y*y + PlaneV.Z*z + PlaneV.D

	-- 0 = PlaneV.X*(lv.X*t + lV0.X) + PlaneV.Y*(lv.Y*t + lV0.Y) + PlaneV.X*(lv.Z*t + lV0.Z) + PlaneV.D
	-- 0 = PlaneV.X*lv.X*t + PlaneV.X*lV0.X + PlaneV.Y*lv.Y*t + PlaneV.Y*lV0.Y + PlaneV.Z*lv.Z*t + PlaneV.Z*lV0.Z + PlaneV.D
	-- PlaneV.X*lv.X*t + PlaneV.Y*lv.Y*t + PlaneV.X*lv.Z*t = - PlaneV.X*lV0.X - PlaneV.Y*lV0.Y - PlaneV.Z*lV0.Z - PlaneV.D
	-- t*(PlaneV.X*lv.X + PlaneV.Y*lv.Y + PlaneV.Z*lv.Z) = - PlaneV.X*lV0.X - PlaneV.Y*lV0.Y - PlaneV.Z*lV0.Z
	-- t = -1*(PlaneV.X*lV0.X + PlaneV.Y*lV0.Y + PlaneV.Z*lV0.Z + PlaneV.D) / (PlaneV.X*lv.X + PlaneV.Y*lv.Y + PlaneV.Z*lv.Z)
	local div = (PlaneV.X*lV.X + PlaneV.Y*lV.Y + PlaneV.Z*lV.Z)
	if div == 0 then
		return {X = -30000, Y = -30000, Z = -30000}
	end

	local t = -1*(PlaneV.X*lV0.X + PlaneV.Y*lV0.Y + PlaneV.Z*lV0.Z + PlaneV.D) / div
	return {X = lV.X * t + lV0.X, Y = lV.Y * t + lV0.Y, Z = lV.Z * t + lV0.Z}
end

function InProjection(V0, List)
	local V1 = Map.Vertexes[List[List.count-1]]
	local V2
	local Sum = 0
	local Angle
	local nV1, nV2
	local Mul
	for i = 0, List.count-1 do
		V2 = Map.Vertexes[List[i]]
		if V1.X == V2.X and V1.Y == V2.Y and V1.Z == V2.Z then
			-- angle = 0
		else
			nV1, nV2 = MakeVec3D(V0, V1), MakeVec3D(V0, V2)
			Angle = GetAngleVec(nV1, nV2)
			if math.round((Angle - math.pi)*10000) == 0 then
				return 361
			end
			Mul = VectorMul(nV1, nV2)
			if Mul.Z > 0 then
				Sum = Sum + Angle
			else
				Sum = Sum - Angle
			end
		end
		V1 = V2
	end
	return ceil(math.deg(abs(Sum)))-- >= 360
end

function TraceWayTEST(From, To)
	local Dist = GetDist2(From, To)
	local lv = MakeVec3D(From, To)

	for i,v in Map.Facets do
		pV1 = Map.Vertexes[v.VertexIds[0]]
		pV2 = Map.Vertexes[v.VertexIds[ceil(v.VertexesCount/2)]]
		pV3 = Map.Vertexes[v.VertexIds[v.VertexesCount-1]]
		PlaneV = PlaneDefiners(pV1, pV2, pV3)

		V0 = PlaneLineIntersection(PlaneV, From, lv)
		if not (GetDist2(V0, From) > Dist or GetDist2(V0, To) > Dist) and InProjection(V0, v.VertexIds) then
			return false
		end
	end
	return true
end

function TraceWayTEST2(From, To)
	local Dist = GetDist2(From, To)
	local lv = MakeVec3D(From, To)

	local MinX, MaxX = min(From.X, To.X), max(From.X, To.X)
	local MinY, MaxY = min(From.Y, To.Y), max(From.Y, To.Y)
	local MinZ, MaxZ = min(From.Z, To.Z), max(From.Z, To.Z)

	for i,v in Map.Facets do
		if v.Invisible and v.Untouchable or v.IsPortal or v.MinX > MaxX or v.MaxX < MinX or v.MinY > MaxY or v.MaxY < MinY or v.MinZ > MaxZ or v.MaxZ < MinZ then
			-- skip
		else
			pV1 = Map.Vertexes[v.VertexIds[0]]
			pV2 = Map.Vertexes[v.VertexIds[ceil(v.VertexesCount/2)]]
			pV3 = Map.Vertexes[v.VertexIds[v.VertexesCount-1]]
			PlaneV = PlaneDefiners(pV1, pV2, pV3)

			V0 = PlaneLineIntersection(PlaneV, From, lv)
			if not (GetDist2(V0, From) > Dist or GetDist2(V0, To) > Dist) and InProjection(V0, v.VertexIds) then
				return false
			end
		end
	end
	return true
end

function TraceWayTEST3(From, To)
	local Dist = GetDist2(From, To)
	local lv = MakeVec3D(From, To)

	local MinX, MaxX = min(From.X, To.X), max(From.X, To.X)
	local MinY, MaxY = min(From.Y, To.Y), max(From.Y, To.Y)
	local MinZ, MaxZ = min(From.Z, To.Z), max(From.Z, To.Z)

	local Room = Map.RoomFromPoint(XYZ(From))
	local Walls = Map.Rooms[Room].Walls

	local v
	for _,i in Walls do
		v = Map.Facets[i]
		if v.Invisible and v.Untouchable or v.IsPortal or v.MinX > MaxX or v.MaxX < MinX or v.MinY > MaxY or v.MaxY < MinY or v.MinZ > MaxZ or v.MaxZ < MinZ then
			-- skip
		else
			pV1 = Map.Vertexes[v.VertexIds[0]]
			pV2 = Map.Vertexes[v.VertexIds[ceil(v.VertexesCount/2)]]
			pV3 = Map.Vertexes[v.VertexIds[v.VertexesCount-1]]
			PlaneV = PlaneDefiners(pV1, pV2, pV3) -- 1

			V0 = PlaneLineIntersection(PlaneV, From, lv) -- 2
			if GetDist2(V0, From) < Dist and GetDist2(V0, To) < Dist and InProjection(V0, v.VertexIds) then -- 3
				return false
			end
		end
	end
	return true
end

function testIntersect()
	lV0 = {X = Party.X, Y = Party.Y, Z = Party.Z}
	lV1 = {X = Party.X, Y = Party.Y, Z = Party.Z + 20}
	lV = MakeVec3D(lV0, lV1)

	_, F = Map.GetFloorLevel(XYZ(Party))

	pV1 = Map.Vertexes[Map.Facets[F].VertexIds[0]]
	pV2 = Map.Vertexes[Map.Facets[F].VertexIds[ceil(Map.Facets[F].VertexesCount/2)]]
	pV3 = Map.Vertexes[Map.Facets[F].VertexIds[Map.Facets[F].VertexesCount-1]]

	PlaneV = PlaneDefiners(pV1, pV2, pV3)

	result = PlaneLineIntersection(PlaneV, lV0, lV)
	print(dump(result))
end

function testIntersect2(F)
	lV0 = {X = Party.X, Y = Party.Y, Z = Party.Z}
	lV1 = {X = Party.X, Y = Party.Y, Z = Party.Z + 20}
	lV = MakeVec3D(lV0, lV1)

	pV1 = Map.Vertexes[Map.Facets[F].VertexIds[0]]
	pV2 = Map.Vertexes[Map.Facets[F].VertexIds[ceil(Map.Facets[F].VertexesCount/2)]]
	pV3 = Map.Vertexes[Map.Facets[F].VertexIds[Map.Facets[F].VertexesCount-1]]

	PlaneV = PlaneDefiners(pV1, pV2, pV3)

	result = PlaneLineIntersection(PlaneV, lV0, lV)
	print(dump(result) .. "\n" .. tostring(InProjection(result, Map.Facets[F].VertexIds)))
end

function testIntersect3()
	lV0 = {X = Party.X, Y = Party.Y, Z = Party.Z}
	lV1 = {X = Party.X, Y = Party.Y + 20, Z = Party.Z}
	lV = MakeVec3D(lV0, lV1)

	for i,v in Map.Facets do
		pV1 = Map.Vertexes[v.VertexIds[0]]
		pV2 = Map.Vertexes[v.VertexIds[ceil(v.VertexesCount/2)]]
		pV3 = Map.Vertexes[v.VertexIds[v.VertexesCount-1]]

		PlaneV = PlaneDefiners(pV1, pV2, pV3)
		result = PlaneLineIntersection(PlaneV, lV0, lV)
		if InProjection(result, v.VertexIds) then
			print(i, dump(result))
		end
	end
end

function testIntersect4(F, lV0, lV1)
	lV = MakeVec3D(lV0, lV1)

	pV1 = Map.Vertexes[Map.Facets[F].VertexIds[0]]
	pV2 = Map.Vertexes[Map.Facets[F].VertexIds[ceil(Map.Facets[F].VertexesCount/2)]]
	pV3 = Map.Vertexes[Map.Facets[F].VertexIds[Map.Facets[F].VertexesCount-1]]

	PlaneV = PlaneDefiners(pV1, pV2, pV3)

	result = PlaneLineIntersection(PlaneV, lV0, lV)
	print(dump(result) .. "\n" .. tostring(InProjection(result, Map.Facets[F].VertexIds)))
end

--------------------------------------------------

local function EqualCoords(a, b, Precision)
	if not Precision then
		return a.X == b.X and a.Y == b.Y and a.Z == b.Z
	else
		return	a.X > b.X - Precision and a.X < b.X + Precision and
				a.Y > b.Y - Precision and a.Y < b.Y + Precision and
				a.Z > b.Z - Precision and a.Z < b.Z + Precision
	end
end

local function GetDist(px, py, pz, x, y, z)
	return sqrt((px-x)^2 + (py-y)^2 + (pz-z)^2)
end

function GetDist2(p1, p2)
	local px, py, pz = XYZ(p1)
	local x, y, z = XYZ(p2)
	return sqrt((px-x)^2 + (py-y)^2 + (pz-z)^2)
end

local function GetDistXY(px, py, x, y)
	return sqrt((px-x)^2 + (py-y)^2)
end

local function DirectionToPoint(From, To)
	local angle, sector
	local X, Y = From.X - To.X, From.Y - To.Y
	local Hy = sqrt(X^2 + Y^2)

	angle = asin(abs(Y)/Hy)
	angle = (angle/rad(90))*512

	if X < 0 and Y < 0 then
		angle = angle + 1024
	elseif X < 0 and Y >= 0 then
		angle = 1024 - angle
	elseif X >= 0 and Y < 0 then
		angle = 2048 - angle
	end

	return floor(angle)
end

local function FacetToPoint(Facet)
	return {X = (Facet.MinX + Facet.MaxX)/2, Y = (Facet.MinY + Facet.MaxY)/2, Z = (Facet.MinZ + Facet.MaxZ)/2}
end

local function DistanceBetweenFacets(f1, f2) -- Approx
	return floor(GetDist2(FacetToPoint(f1), FacetToPoint(f2)))
end

local function AreaOfTarget(Target)
	local _, FacetId = Map.GetFloorLevel(XYZ(Target))
	if not HaveMapData then
		return FacetId
	end

	local result = MapFloors[FacetId]
	if not result then
		local Dist, LastDist, TargetArea = 0, 1/0, 1
		for AreaId, Area in pairs(MapAreas) do
			Dist = GetDist2(Target, Area.WayPoint)
			if Dist < LastDist then
				LastDist, TargetArea = Dist, AreaId
			end
		end
		result = TargetArea
	end
	return result or 0
end
Pathfinder.AreaOfTarget = AreaOfTarget

local function SharedVertexes(f1, f2)
	local count = 0
	for i1,v1 in f1.VertexIds do
		for i2, v2 in f2.VertexIds do
			if EqualCoords(Map.Vertexes[v1], Map.Vertexes[v2], 5) then
				count = count + 1
			end
		end
	end
	return count
end

local function FacetS(Facet)
	-- Approximation with ignoring Z size
	local cV, pV
	local sum = 0
	for i,v in Facet.VertexIds do
		pV = cV or Map.Vertexes[Facet.VertexIds[Facet.VertexesCount-1]]
		cV = Map.Vertexes[v]
		sum = sum + pV.X*cV.Y
	end
	cV, pV = nil, nil
	for i,v in Facet.VertexIds do
		pV = cV or Map.Vertexes[Facet.VertexIds[Facet.VertexesCount-1]]
		cV = Map.Vertexes[v]
		sum = sum - pV.Y*cV.X
	end
	return abs(floor(sum/2))
end
--------------------------------------------------
--					Tracer						--
--------------------------------------------------

local function TraceSight(From, To)
	return mem.call(Pathfinder.TraceLineAsm, 0, 0, 0, From.X, From.Y, From.Z+5, To.X, To.Y, To.Z+5) == 1
end

function TraceMonWayAsm(MonId, Monster, From, To, Radius)
	return mem.call(Pathfinder.TraceAsm, 0, MonId, Radius, From.X, From.Y, From.Z, To.X, To.Y, To.Z) == 1
end

--------------------------------------------------
--				Way generation					--
--------------------------------------------------
local function ShrinkMonWay(WayMap, MonId, StepSize, Async)
	MonId = MonId or 1
	StepSize = StepSize or #WayMap
	local Current = 1
	local Monster = Map.Monsters[MonId]
	local TraceRadius = ceil(Monster.BodyRadius/3)

	local ptr = Monster["?ptr"] + 0x92
	local Buf = mem.string(ptr, 0x32, true)

	while Current < #WayMap do
		for i = min(Current + StepSize, #WayMap), Current + 1, -1 do
			if TraceMonWayAsm(MonId, Monster, WayMap[Current], WayMap[i], TraceRadius) then
				for _ = Current + 1, i - 1 do
					tremove(WayMap, Current + 1)
				end
				break
			end
		end
		Current = Current + 1
		if Async and timeGetTime() > TickEndTime then
			mem.copy(ptr, Buf)
			coyield()
			Buf = mem.string(ptr, 0x32, true)
		end
	end

	mem.copy(ptr, Buf)
	return WayMap
end
Pathfinder.ShrinkWay = ShrinkMonWay

local function Heuristic(FromCell, ToCell, MonId, Monster, Target, TraceRadius)
	local Cost = 100000000
	if TraceMonWayAsm(MonId, Monster, FromCell, ToCell, TraceRadius) then
		Cost = 1
		ToCell.Z = Monster.Z
	else
		-- Placeholder for jump logic
		return Cost
	end

	Cost = Cost
		+ ToCell.Length
		+ ceil(GetDist2(ToCell, Target))

	return Cost
end

local function AStarWayLua(MonId, Monster, Target, AvAreas, Async, CustomStart, limit)

	local inf = 100000000
	limit = limit or inf

	local ptr = Monster["?ptr"] + 0x92
	local size = 0x32
	local Buf = mem.string(ptr, size, true)
	local NextCell
	local CellHeight = Monster.BodyHeight
	local CellRadius = Monster.BodyRadius*2
	local TraceRadius = ceil(Monster.BodyRadius/3)

	local function CellName(cX, cY, cZ)
		return tostring(cX) .. tostring(cY) .. tostring(cZ)
	end

	local X, Y, Z, F
	if CustomStart then
		X,Y,Z = XYZ(CustomStart)
	else
		X,Y,Z = XYZ(Monster)
	end

	AllCells = {{Id = 1, X = X, Y = Y, Z = Z, StableZ = Z, Cost = 1, Length = 0, From = 0}}
	local Reachable = {1}
	local WayMap = {}
	local LastKey, LastCost, ThisCost
	local NextStep
	local Cell
	local PathFound = false
	local count = 0

	local function CellExplored(cX, cY, cZ)
		for k,v in pairs(AllCells) do
			if cX == v.X and cY == v.Y and cZ == v.StableZ then
				return true
			end
		end
		return false
	end

	local CellValid
	if AvAreas then
		CellValid = function(cX, cY, cZ, FacetId)
			return not CellExplored(cX, cY, cZ) and AvAreas[MapFloors[FacetId] or -1]
		end
	else
		CellValid = function(cX, cY, cZ, FacetId)
			return not CellExplored(cX, cY, cZ)
		end
	end

	local CheckTime
	if Async then
		CheckTime = function()
			if timeGetTime() > TickEndTime then
				mem.copy(ptr, Buf)
				coyield(count)
				Buf = mem.string(ptr, size, true)
			end
		end
	else
		CheckTime = function() return false end
	end
	CheckTime()

	while #Reachable > 0 do
		NextStep, LastCost, LastKey = 1, inf, 1
		for k,v in pairs(Reachable) do
			ThisCost = AllCells[v].Cost
			if LastCost > ThisCost then
				NextStep, LastCost, LastKey = v, ThisCost, k
			end
		end
		tremove(Reachable, LastKey)
		NextStep = AllCells[NextStep]

		if GetDist2(NextStep, Target) <= CellRadius + 200 then
			PathFound = true
			break
		end

		count = count + 1
		if count > limit then
			break
		end

		for DirId, Dir in pairs(AllowedDirections) do
			CheckTime()
			X = NextStep.X + CellRadius*Dir.X
			Y = NextStep.Y + CellRadius*Dir.Y
			Z = NextStep.Z + CellHeight*Dir.Z
			Z, F = Map.GetFloorLevel(X, Y, Z)

			if Z <= -29000 then
				Z = Map.Facets[F].MinZ
			end

			if CellValid(X, Y, Z, F) then
				Cell = {
					Id = 0,
					X = X,
					Y = Y,
					Z = Z,
					StableZ = Z,
					Cost = 0,
					Length = ceil(GetDist(NextStep.X, NextStep.Y, NextStep.Z, X, Y, Z) + NextStep.Length),
					From = NextStep.Id
					}

				Cell.Cost = Heuristic(NextStep, Cell, MonId, Monster, Target, TraceRadius)
				if Cell.Cost < inf then
					Cell.Id = #AllCells + 1
					AllCells[Cell.Id] = Cell
					tinsert(Reachable, Cell.Id)
				end
			end
		end
	end

	if PathFound then
		Cell = NextStep
		while Cell.Id ~= 1 do
			tinsert(WayMap, 1, Cell)
			Cell = AllCells[Cell.From]
		end
	end

	mem.copy(ptr, Buf)
	return WayMap, count
end
Pathfinder.AStarWayLua = AStarWayLua

local function AStarWay(MonId, Monster, Target, AvAreas, Async, CustomStart, limit)
	if Pathfinder.AStarWayAsm then
		local t = {MonId = MonId, ToX = Target.X, ToY = Target.Y, ToZ = Target.Z, Async = Async, AvAreas = AvAreas}
		if CustomStart then
			t.FromX = CustomStart.X
			t.FromY = CustomStart.Y
			t.FromZ = CustomStart.Z
		end
		return Pathfinder.AStarWayAsm(t)
	else
		return AStarWayLua(MonId, Monster, Target, AvAreas, Async, CustomStart, limit)
	end
end
Pathfinder.AStarWay = AStarWay

local function NeighboursWay(FromArea, ToArea, Async, limit)
	local Reachable = {FromArea}
	local AreaWay = {}
	local Explored = {[FromArea] = true}
	local CurArea = FromArea
	local PathFound = false
	local Way = {}
	local count = 0
	local limit = limit or 1/0

	while #Reachable > 0 do
		for k,v in pairs(Reachable) do
			CurArea = v
			tremove(Reachable, k)
			break
		end

		if CurArea == ToArea then
			PathFound = true
			break
		end

		count = count + 1
		if count > limit then
			break
		end

		for k,v in pairs(MapAreas[CurArea].Neighbours) do
			if not Explored[k] then
				AreaWay[k] = CurArea
				tinsert(Reachable, k)
				Explored[k] = true
			end
		end

		if Async and timeGetTime() > TickEndTime then
			coyield()
		end
	end

	if PathFound then
		while CurArea ~= FromArea do
			tinsert(Way, 1, CurArea)
			CurArea = AreaWay[CurArea]
		end
	end

	return Way
end
Pathfinder.NWay = NeighboursWay

--------------------------------------------------
--				Import/Export					--
--------------------------------------------------
local function ImportAreasInfo(Path)
	HaveMapData = false
	Path = Path or "Data/BlockMaps/" .. Map.Name .. ".txt"
	local File = io.open(Path, "r")

	if not File then
		return false
	end

	local Floors, Areas, NWays = {}, {}, {}
	local LineIt = File:lines()
	local Words, Items, Area, Ways, Val
	for line in LineIt do
		Words = string.split(line, "\9")
		if Words[1] == "*" then
			Area = Areas[tonumber(Words[2])]
			Way = Area.Ways[tonumber(Words[3])]
			if not Way then
				Way = {}
				Area.Ways[tonumber(Words[3])] = Way
			end
			tinsert(Way, {
				X = tonumber(Words[4]),
				Y = tonumber(Words[5]),
				Z = tonumber(Words[6]),
				StableZ = tonumber(Words[7]),
				NeedJump = Words[8] == "X"})
		elseif Words[1] == ">" then
			Area = tonumber(Words[2])
			Val = tonumber(Words[3])
			Items = string.split(Words[4] or "", "|")
			if Area and Val and #Items > 0 then
				for i,v in pairs(Items) do
					Items[i] = tonumber(v)
				end
				NWays[Area] = NWays[Area] or {}
				NWays[Area][Val] = Items
			end
		else
			Area = tonumber(Words[1])
			if Area then
				Areas[Area] = {
				Id = Area,
				WayPoint = {X = tonumber(Words[2]), Y = tonumber(Words[3]), Z = tonumber(Words[4])},
				S = tonumber(Words[5]),
				Ways = {},
				Floors = {},
				Neighbours = {}}

				Area = Areas[Area]

				Items = string.split(Words[6], "|")
				for k,v in pairs(Items) do
					Val = tonumber(v)
					if Val then
						tinsert(Area.Floors, Val)
					end
				end

				Items = string.split(Words[7], "|")
				for k,v in pairs(Items) do
					Val = tonumber(v)
					if Val then
						Area.Neighbours[Val] = true
					end
				end
			end
		end
	end

	for AreaId, Area in pairs(Areas) do
		for _,F in pairs(Area.Floors) do
			Floors[F] = AreaId
		end
	end

	io.close(File)
	MapFloors, MapAreas, NeighboursWays = Floors, Areas, NWays
	HaveMapData = true
	return Floors, Areas, NWays
end

local function ExportAreasInfo(Areas, NWays, Path)
	Path = Path or "Data/BlockMaps/" .. Map.Name .. ".txt"
	File = io.open(Path, "w")

	local cNeighbours
	for _, Area in pairs(Areas) do
		cNeighbours = {}
		for AreaId, NeighId in pairs(Area.Neighbours) do
			tinsert(cNeighbours, AreaId)
		end

		File:write(
			Area.Id .. "\9" ..
			Area.WayPoint.X .. "\9" ..
			Area.WayPoint.Y .. "\9" ..
			Area.WayPoint.Z .. "\9" ..
			Area.S .. "\9" ..
			table.concat(Area.Floors, "|") .. "\9" ..
			table.concat(cNeighbours, "|") .. "\n")

		for AreaId, Way in pairs(Area.Ways) do
			for __, P in ipairs(Way) do
				File:write(
					"*\9" ..
					Area.Id .. "\9" ..
					AreaId .. "\9" ..
					P.X .. "\9" ..
					P.Y .. "\9" ..
					P.Z .. "\9" ..
					(P.StableZ or P.Z) .. "\9" ..
					(P.NeedJump and "X" or "-") .. "\n")
			end
		end
	end
	for FromA, Ways in pairs(NWays) do
		for ToA, Way in pairs(Ways) do
			File:write(">\9" .. FromA .. "\9" .. ToA .. "\9" .. table.concat(Way, "|") .. "\n")
		end
	end
	io.close(File)
end

local function MakeWayPoints()

	local Floors, Areas, NWays = ImportAreasInfo(Path)
	if Floors then
		MapFloors, MapAreas = Floors, Areas
		if Pathfinder then
			Pathfinder.BakeFloors(Floors)
		end
		return Floors, Areas, NWays
	end

	Floors, Areas, NWays = {}, {}, {}
	local MaxAreaSize = 6000000
	local MinAreaSize = 500000
	local StartTime = os.time()
	local Log = {}
	local counter = 0

	-- Init facets (FacetId = AreaId)
	for i,v in Map.Facets do
		if v.PolygonType == 3 or v.PolygonType == 4 or v.IsPortal then -- and not (v.IsPortal or v.Invisible or v.Untouchable)
			Floors[i] = 0
		end
	end

	for i,v in Map.Doors do
		for _, F in v.FacetIds do
			Floors[F] = 0
		end
	end

	-- Make Areas
	local CurArea
	local TotalS = 0
	local FoundAnother
	local f1, f2

	for FacetId, AreaId in pairs(Floors) do
		if AreaId == 0 then
			CurArea = {Id = #Areas + 1, Floors = {FacetId}, Neighbours = {}, Ways = {}, WayPoint = {X = 0, Y = 0, Z = 0}, S = 0}
			Floors[FacetId] = CurArea.Id
			Areas[CurArea.Id] = CurArea
			TotalS = 0
			FoundAnother = true
			while TotalS < MaxAreaSize and FoundAnother do
				FoundAnother = false
				for F, A in pairs(Floors) do
					if A == 0 and TotalS < MaxAreaSize then
						for k,v in pairs(CurArea.Floors) do
							f1 = Map.Facets[F]
							f2 = Map.Facets[v]
							if f1.Room == f2.Room and SharedVertexes(f1, f2) > 1 then
								tinsert(CurArea.Floors, F)
								Floors[F] = CurArea.Id
								TotalS = TotalS + FacetS(f1)
								CurArea.S = TotalS
								FoundAnother = true
								break
							end
						end
					end
				end
			end
		end
	end
	tinsert(Log, "Making areas: " .. os.time() - StartTime)

	-- Unassign facets from small areas
	local cNeighbours, SharedAmount
	for AreaId, Area in pairs(Areas) do
		if Area.S < MinAreaSize then
			cNeighbours = {}
			for AId, A in pairs(Areas) do
				if AreaId ~= AId then
					SharedAmount = 0
					for _, F1 in pairs(Area.Floors) do
						for __, F2 in pairs(A.Floors) do
							SharedAmount = SharedAmount + SharedVertexes(Map.Facets[F1], Map.Facets[F2])
							if SharedAmount > 2 then
								tinsert(cNeighbours, AId)
								break
							end
						end
					end
				end
			end

			if #cNeighbours > 0 then
				CurArea = cNeighbours[1]
				for k,v in pairs(cNeighbours) do
					if Areas[CurArea].S < Areas[v].S then
						CurArea = v
					end
				end
				CurArea = Areas[CurArea]
				CurArea.S = CurArea.S + Area.S
				Area.S = 0
				for k,v in pairs(Area.Floors) do
					Floors[v] = CurArea.Id
					Area.Floors[k] = nil
					tinsert(CurArea.Floors, v)
				end
			else
				for k,v in pairs(Area.Floors) do
					Floors[v] = 0
					Area.Floors[k] = nil
				end
				Area.S = 0
				XYZ(Area.WayPoint, -30000, -30000, -30000)
			end
		end
	end
	tinsert(Log, "Merging areas, step 1: " .. os.time() - StartTime)

	-- Rebuild array
	local Rebuild = {}
	for k,v in pairs(Areas) do
		if v.S ~= 0 then
			v.Id = #Rebuild + 1
			for _,F in pairs(v.Floors) do
				Floors[F] = v.Id
			end
			Rebuild[v.Id] = v
		end
	end
	Areas = Rebuild

	-- Remove empty areas and reassign facets to larger neighbours.
	local Distances
	local LastDist
	for FacetId, AreaId in pairs(Floors) do
		f1 = Map.Facets[FacetId]
		CurArea = nil
		if AreaId == 0 then
			Distances = {}
			for AId, Area in pairs(Areas) do
				for _,F in pairs(Area.Floors) do
					if SharedVertexes(f1, Map.Facets[F]) > 1 then
						CurArea = AId
						break
					end
					Distances[AId] = min(Distances[AId] or 1/0, DistanceBetweenFacets(f1, Map.Facets[F]))
				end
				if CurArea then
					break
				end
			end
			if not CurArea then
				LastDist = 1/0
				for AId, Dist in pairs(Distances) do
					if Dist < LastDist then
						LastDist = Dist
						CurArea = AId
					end
				end
			end
			Floors[FacetId] = CurArea or 0
			tinsert(Areas[CurArea].Floors, FacetId)
		end
	end

	-- Set way points
	local S, LastS
	for AreaId, Area in pairs(Areas) do
		LastS = 0
		for _, F in pairs(Area.Floors) do
			S = FacetS(Map.Facets[F])
			if S > LastS then
				LastS = S
				f1 = F
			end
		end
		XYZ(Area.WayPoint, XYZ(FacetToPoint(Map.Facets[f1])))
	end
	tinsert(Log, "Merging areas, step 2: " .. os.time() - StartTime)

	-- Build ways
	MapAreas, MapFloors, NeighboursWays = Areas, Floors, NWays
	if Pathfinder then
		Pathfinder.BakeFloors(Floors)
	end
	local Mon, MonId = SummonMonster(1, XYZ(Party))
	local MapInTxt = Game.MapStats[Map.MapStatsIndex]
	Mon.AIState = const.AIState.Removed

	local function tmoTargetArea(target)
		local _, F = Map.GetFloorLevel(XYZ(target))
		return Floors[F] or 0
	end

	local Way, NextV, A1, A2
	for AreaId, Area in pairs(Areas) do
		for AId, A in pairs(Areas) do
			if AreaId ~= AId and not Area.Neighbours[AId] and not Area.Ways[AId] then
				Way = AStarWay(MonId, Mon, A.WayPoint, nil, false, Area.WayPoint)
				if #Way > 0 then
					while tmoTargetArea(Way[2]) == AreaId do
						tremove(Way, 1)
					end
					for i,v in ipairs(Way) do
						NextV = Way[i+1] or v
						A1 = tmoTargetArea(v)
						A2 = tmoTargetArea(NextV)
						if A1 ~= A2 and Areas[A1] and Areas[A2] then
							counter = counter + 1
							Areas[A1].Neighbours[A2] = true
							Areas[A2].Neighbours[A1] = true
						end
					end
					if not Area.Neighbours[AId] then
						ShrinkMonWay(Way, MonId, 3, false)
						Area.Ways[AId] = Way
						A.Ways[AreaId] = Way
					end
				end
			end
		end
		collectgarbage("collect")
	end
	tinsert(Log, "Building ways: " .. os.time() - StartTime .. ", neighbours found: " .. counter)
	counter = 0

	-- Find rest neighbours
	for AreaId, Area in pairs(Areas) do
		for AId, A in pairs(Areas) do
			if not (AreaId == AId or Area.Neighbours[AId] or Area.Ways[AId]) then
				for _, F1 in pairs(Area.Floors) do
					for __, F2 in pairs(A.Floors) do
						if SharedVertexes(Map.Facets[F1], Map.Facets[F2]) > 1 then
							Area.Neighbours[AId] = true
							A.Neighbours[AreaId] = true
							break
						end
					end
					if Area.Neighbours[AId] then
						break
					end
				end
			end
		end
	end
	tinsert(Log, "Seeking neighbours: " .. os.time() - StartTime)

	-- Bake neighbour ways
	for AreaId, Area in pairs(Areas) do
		NWays[AreaId] = {}
		for AId, A in pairs(Areas) do
			if AreaId == AId then
				NWays[AreaId][AId] = {}
			else
				NWays[AreaId][AId] = NeighboursWay(AreaId, AId, false)
			end
		end
	end
	NeighboursWays = NWays
	tinsert(Log, "Baking neighbour ways: " .. os.time() - StartTime)

	-- TEST: Display areas
	--for AId,Area in pairs(Areas) do
	--	for k,v in pairs(Area.Floors) do
	--		Map.Facets[v].BitmapId = AId + 100
	--	end
	--end

	ExportAreasInfo(Areas, NWays)
	HaveMapData = true
	return table.concat(Log, "\n")
end
Pathfinder.MakeWayPoints = MakeWayPoints

--------------------------------------------------
--				Game handler					--
--------------------------------------------------
local AStarQueue = {}
Pathfinder.AStarQueue = AStarQueue

local function AStarQueueSort(v1, v2)
	return v1.Dist < v2.Dist
end
local function SortQueue()
	local Way, v, Mon
	for i = #AStarQueue, 1, -1 do
		v = AStarQueue[i]
		if v.MonId >= Map.Monsters.count then
			tremove(AStarQueue, i)
		elseif HaveMapData then
			Way = NeighboursWays[AreaOfTarget(Map.Monsters[v.MonId])]
			Way = Way and Way[AreaOfTarget(MonsterWays[v.MonId])]
			v.Dist = Way and #Way > 0 and #Way or 1/0
			if Map.Monsters[v.MonId].Fly == 1 then
				v.Dist = v.Dist + 10
			end
			v.Dist = v.Dist + v.MonWay.FailCount*10
		else
			Mon = Map.Monsters[v.MonId]
			v.Dist = GetDist2(Mon, v.Target)
			if Map.Monsters[v.MonId].Fly == 1 then
				v.Dist = v.Dist + 1000
			end
			v.Dist = v.Dist + v.MonWay.FailCount*1000
		end
	end
	table.sort(AStarQueue, AStarQueueSort)
end

local function ProcessThreads()
	if #AStarQueue == 0 then
		return
	end

	TickEndTime = timeGetTime() + 3
	SortQueue()

	local co = AStarQueue[1] and AStarQueue[1].co
	while co and timeGetTime() < TickEndTime do
		if costatus(co) == "dead" then
			tremove(AStarQueue, 1)
			co = AStarQueue[1] and AStarQueue[1].co
		else
			testResult, testError = coresume(co)
			if type(testError) == "string" then
				debug.Message(testError)
			end
		end
	end
end

local function BuildWayUsingMapData(FromArea, ToArea, MonId, Monster, Target, Async)
	local WayMap
	if not HaveMapData or Monster.Fly == 1 or ToArea == 0 then
		WayMap = AStarWay(MonId, Monster, Target, nil, Async)

	elseif FromArea == ToArea then
		WayMap = AStarWay(MonId, Monster, Target, {[FromArea] = true}, Async)

	elseif MapAreas[FromArea].Neighbours[ToArea] then
		WayMap = AStarWay(MonId, Monster, Target, {[FromArea] = true, [ToArea] = true}, Async)

	else
		local ExistingWay = MapAreas[FromArea].Ways[ToArea]
		local AreaWay = NeighboursWays[FromArea][ToArea]

		if #AreaWay > 10 then
			TooFar = true

		elseif ExistingWay and #ExistingWay > 0 then
			WayMap = AStarWay(MonId, Monster, ExistingWay[1], {[FromArea] = true, [AreaOfTarget(ExistingWay[1])] = true}, Async)
			for i,v in ipairs(ExistingWay) do
				tinsert(WayMap, v)
			end

		elseif #AreaWay > 0 then
			local CurWay
			for i,v in ipairs(AreaWay) do
				CurWay = MapAreas[FromArea].Ways[v]
				if CurWay and #CurWay > 0 then
					WayMap = CurWay
				else
					break
				end
			end
			if WayMap then
				CurWay = AStarWay(MonId, Monster, WayMap[1], {[FromArea] = true}, Async)
				for i,v in ipairs(WayMap) do
					tinsert(CurWay, v)
				end
				WayMap = CurWay
			else
				WayMap = AStarWay(MonId, Monster, MapAreas[AreaWay[1]].WayPoint, {[FromArea] = true, [AreaWay[1]] = true}, Async)
			end

		else
			WayMap = AStarWay(MonId, Monster, Target, nil, Async)
		end
	end
	return WayMap
end

local function MakeMonWay(cMonWay, cMonId, cTarget)
	cMonWay.InProcess = true
	cMonWay.NeedRebuild = false
	cMonWay.X = cTarget.X
	cMonWay.Y = cTarget.Y
	cMonWay.Z = cTarget.Z
	coyield()

	cMonWay.HoldMonster = true
	local WayMap
	local Monster = Map.Monsters[cMonId]
	local TooFar = false
	local FromArea, ToArea = AreaOfTarget(Monster), AreaOfTarget(cTarget)

	WayMap = BuildWayUsingMapData(FromArea, ToArea, cMonId, Monster, cTarget, true)

	if #WayMap > 0 then
		test3 = true
		cMonWay.GenTime = Game.Time
		cMonWay.FailCount = 0
	else
		test3 = false
		 -- delay next generation if previous one failed
		cMonWay.FailCount = cMonWay.FailCount + 1
		cMonWay.GenTime = Game.Time + const.Minute*4
	end
	Monster.AIState = 6
	cMonWay.WayMap = WayMap
	cMonWay.Step = 1
	cMonWay.TargetArea = ToArea
	cMonWay.Size = #cMonWay.WayMap
	cMonWay.HoldMonster = false
	cMonWay.InProcess = false
end

local function SetQueueItem(MonWay, MonId, Target)
	local co = cocreate(MakeMonWay)
	coresume(co, MonWay, MonId, Target)
	tinsert(AStarQueue, {co = co, MonId = MonId, Dist = ceil(GetDist2(Map.Monsters[MonId], Target)), Target = Target, MonWay = MonWay})
end

local function StuckCheck(MonId, Monster)
	if Map.RoomFromPoint(Monster) == 0 then
		return true
	end

	MonStuck[MonId] = MonStuck[MonId] or {X = 0, Y = 0, Z = 0, Time = Game.Time, Stuck = 0}
	local StuckCheck = MonStuck[MonId]
	if Monster.AIState == 6 and EqualCoords(StuckCheck, Monster) then
		StuckCheck.Stuck = Game.Time - StuckCheck.Time
		if StuckCheck.Stuck > 512 then
			StuckCheck.Stuck = 0
			return true
		end
	else
		StuckCheck.Time = Game.Time
		StuckCheck.Stuck = 0
		StuckCheck.X = Monster.X
		StuckCheck.Y = Monster.Y
		StuckCheck.Z = Monster.Z
	end

	return false
end

local NextMon = 0
local function ProcessNextMon()
	if Game.TurnBased == 1 then
		return
	end

	local Target, Monster, MonWay
	local count = 0
	if NextMon >= Map.Monsters.count then
		NextMon = 0
	end

	for MonId = NextMon, Map.Monsters.count - 1 do
		if count > 20 then
			break
		end

		count = count + 1
		NextMon = MonId + 1
		Monster = Map.Monsters[MonId]

		if Monster.Active and Monster.HP >= 0 and Monster.AIState == 6 then
			Target = Party -- Only Party at the moment
			MonWay = MonsterWays[MonId] or {
				WayMap = {},
				NeedRebuild = true,
				InProcess = false,
				TargetInSight = false,
				GenTime	= 0,
				StuckTime = 0,
				TargetArea = 0,
				Size = 0,
				Step = 0,
				FailCount = 0}

			MonsterWays[MonId] = MonWay
			MonWay.TargetInSight = GetDist2(Target, Monster) < 1000 and TraceSight(Monster, Target) and TraceSight(Target, Monster)

			if StuckCheck(MonId, Monster) then
				if #MonWay.WayMap > 0 and MonWay.Step > 1 and MonWay.Step <= #MonWay.WayMap then
					XYZ(Monster, XYZ(MonWay.WayMap[MonWay.Step-1]))
					Monster.Z = Monster.Z + 5
				end
				MonWay.NeedRebuild = true
			end

			if not Target or MonWay.TargetInSight then
				-- skip

			elseif MonWay.HoldMonster then
				Monster.MoveType = 1
				Monster.GraphicState = 0
				Monster.AIState = 0
				Monster.CurrentActionLength = TimerPeriod + 10
				Monster.CurrentActionStep = 0

			elseif MonWay.NeedRebuild then
				if MonWay.InProcess then
					MonWay.NeedRebuild = false
				elseif #AStarQueue < 50 then
					SetQueueItem(MonWay, MonId, Target)
				end

			elseif #MonWay.WayMap > 0 then
				local Way = MonWay.WayMap[MonWay.Step]

				Monster.MoveType = 1
				Monster.GraphicState = 1
				Monster.AIState = 6
				Monster.CurrentActionLength = TimerPeriod + 10
				Monster.CurrentActionStep = 0

				if Way.Z < Monster.Z - 35 then
					local StableZ = Map.GetFloorLevel(XYZ(Monster))
					if abs(StableZ - Monster.Z) < 5 then
						Monster.VelocityZ = 500
					end
				end

				if not MonWay.InProcess and AreaOfTarget(Target) ~= MonWay.TargetArea then
					MonWay.NeedRebuild = true
				end

			elseif MonWay.InProcess then
				-- let it roam
			else
				if Game.Time - MonWay.GenTime > const.Minute*4 then
					MonWay.NeedRebuild = true
				end
			end
		end
	end
end

local function PositionCheck()
	if Game.TurnBased == 1 then
		return
	end

	local Monster
	for k,v in pairs(MonsterWays) do
		if k >= Map.Monsters.count then
			MonsterWays[k] = nil
			return
		end
		Monster = Map.Monsters[k]
		if not v.TargetInSight and Monster.AIState == 6 and v.WayMap and v.Size > 0 then
			local WayPoint = v.WayMap[v.Step]
			if WayPoint then
				Monster.Direction = DirectionToPoint(WayPoint, Monster)
				if GetDistXY(WayPoint.X, WayPoint.Y, Monster.X, Monster.Y) < Monster.BodyRadius then
					if v.Step >= v.Size then
						v.WayMap = {}
						v.Size = 0
						if not v.InProcess then
							v.NeedRebuild = true
						end
					else
						v.Step = v.Step + 1
					end
				end
			elseif not v.InProcess and Game.Time > MonWay.GenTime then
				v.NeedRebuild = true
			end
		end
	end
end

function events.AfterLoadMap()
	if not Game.ImprovedPathfinding or Map.IsOutdoor() then -- does not support outdoor maps yet.
		return
	end
	MapFloors, MapAreas, NeighboursWays = {}, {}, {}
	ImportAreasInfo()
	Pathfinder.HaveMapData = HaveMapData
	Pathfinder.MapFloors = MapFloors
	Pathfinder.MapAreas = MapAreas
	Pathfinder.NWays = NeighboursWays

	function events.Tick()
		ProcessNextMon()
		ProcessThreads()
		PositionCheck()
	end
	if Pathfinder.BakeFloors then
		Pathfinder.BakeFloors(MapFloors)
	end
end

----------------------------------------------
--					SERVICE					--
----------------------------------------------

--TestPerfomance(AStarWay, 10, 2, Map.Monsters[2], Party, nil, false, MapAreas[16].WayPoint)
--~ function TestPerfomance(f, loopamount, ...)
--~ 	loopamount = loopamount or 100
--~ 	local Start = timeGetTime()
--~ 	for i = 1, loopamount do
--~ 		f(...)
--~ 	end
--~ 	return timeGetTime() - Start
--~ end

--~ function ShowWay(WayMap, Pause)
--~ 	Pause = Pause or 300
--~ 	local Step = 1
--~ 	local PrevCell, NextCell = WayMap[Step], WayMap[Step + 1]
--~ 	while NextCell do
--~ 		Party.X = NextCell.X
--~ 		Party.Y = NextCell.Y
--~ 		Party.Z = NextCell.Z + 5
--~ 		Sleep(Pause,Pause)

--~ 		Step = Step + 1
--~ 		PrevCell, NextCell = WayMap[Step], WayMap[Step + 1]
--~ 	end
--~ end

--~ function ClosestMonster()
--~ 	local MinDist, Mon = 30000, 123
--~ 	for i,v in Map.Monsters do
--~ 		local Dist = GetDist2(Party, v)
--~ 		if MinDist > Dist then
--~ 			MinDist, Mon = Dist, i
--~ 		end
--~ 	end
--~ 	return Mon
--~ end

--~ function ClosestItem(t)
--~ 	local MinDist, Mon = 1/0, nil
--~ 	for i,v in pairs(t) do
--~ 		local Dist = GetDist2(Party, v)
--~ 		if MinDist > Dist then
--~ 			MinDist, Mon = Dist, i
--~ 		end
--~ 	end
--~ 	return Mon
--~ end

--~ function GetPoint(t)
--~ 	return {X = t.X, Y = t.Y, Z = t.Z} -- -1215 -1206
--~ end

--~ function events.AfterLoadMap()
--~ 	function CreateTESTWidget()
--~ 		TESTWidget = CustomUI.CreateText{Text = "", Key = "TESTWidget", X = 200, Y = 240, Width = 400, Height = 100}

--~ 		local function WidgetTimer()
--~ 			TESTWidget.Text = Party.X .. " : " .. Party.Y .. " : " .. Party.Z .. " - " .. mem.call(Pathfinder.AltGetFloorLevelAsm, 0, Party.X, Party.Y, Party.Z)
--~ 			TESTWidget.Text = TESTWidget.Text .. " q: " .. #AStarQueue .. " r: " .. tostring(test3)
--~ 			Game.NeedRedraw = true
--~ 		end

--~ 		Timer(WidgetTimer, const.Minute/64)
--~ 	end
--~ 	CreateTESTWidget()
--~ end

