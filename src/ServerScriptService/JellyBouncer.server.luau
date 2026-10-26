--!strict
--[[
	Скрипт: JellyBouncer.server.luau
	Назначение: Механика "Пружинящее желе" (мармеладный батут).
	
	Как это работает:
	1. Мы ищем любые блоки в игре с волшебной наклейкой (тегом) "Jelly".
	2. Когда персонаж игрока наступает на мармеладку, скрипт находит его тело.
	3. Затем батут подбрасывает персонажа высоко вверх с помощью физики!
	4. Есть защита (debounce), чтобы батут пружинил мягко и не спамил толчками.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

-- Настройки мармеладного батута
local JELLY_TAG = "Jelly"              -- Тег для поиска батутов
local BOUNCE_POWER = 100               -- Сила прыжка вверх (по оси Y)
local COOLDOWN_TIME = 0.5              -- Перезарядка (в секундах) для каждого персонажа

-- Таблица для памяти: здесь мы записываем время, когда персонаж прыгал в последний раз
local lastBounceTime: { [Model]: number } = {}

-- Функция настройки одного мармеладного блока
local function setupJelly(part: Instance)
	-- Проверяем, что это физическая деталь (BasePart), на которую можно наступить
	if not part:IsA("BasePart") then
		return
	end

	-- Подключаем датчик касания (Touched)
	local connection = part.Touched:Connect(function(otherPart: BasePart)
		-- Узнаем, кто или что коснулось мармеладки
		local character = otherPart.Parent
		if not character or not character:IsA("Model") then
			return
		end

		-- Ищем "гуманоида" — он есть только у живых существ и персонажей игроков
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return -- Если это не живой персонаж, пропускаем
		end

		-- Ищем главную часть тела (HumanoidRootPart) — именно она управляет перемещением
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not rootPart then
			return
		end

		-- Защита от спама (Debounce / Перезарядка):
		-- Проверяем, прошло ли полсекунды с момента прошлого прыжка этого персонажа
		local currentTime = os.clock()
		local lastTime = lastBounceTime[character] or 0

		if currentTime - lastTime < COOLDOWN_TIME then
			return -- Персонаж коснулся желе только что, повторно не подбрасываем
		end

		-- Запоминаем текущее время прыжка
		lastBounceTime[character] = currentTime

		-- Задаем персонажу скорость (AssemblyLinearVelocity):
		-- Сохраняем его движение влево-вправо (X) и вперед-назад (Z),
		-- а по высоте (Y) задаем мощный толчок вверх!
		local currentVelocity = rootPart.AssemblyLinearVelocity
		rootPart.AssemblyLinearVelocity = Vector3.new(currentVelocity.X, BOUNCE_POWER, currentVelocity.Z)
	end)

	-- Если блок желе удалят с фабрики, отключаем датчик касания, чтобы не тратить память
	part.Destroying:Connect(function()
		connection:Disconnect()
	end)
end

-- 1. Подключаем все мармеладки, которые уже расставлены на карте при запуске игры
for _, instance in CollectionService:GetTagged(JELLY_TAG) do
	task.spawn(setupJelly, instance)
end

-- 2. Следим за появлением новых мармеладок (если их спавнят во время игры)
CollectionService:GetInstanceAddedSignal(JELLY_TAG):Connect(setupJelly)

-- Очищаем память, если игрок покидает игру
Players.PlayerRemoving:Connect(function(player)
	local character = player.Character
	if character then
		lastBounceTime[character] = nil
	end
end)
