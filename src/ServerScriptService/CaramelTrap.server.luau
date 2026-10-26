--!strict
--[[
	Скрипт: CaramelTrap.server.luau
	Назначение: Механика "Смертельная карамель" (классический kill-brick для обби).
	
	Как это работает:
	1. Мы отслеживаем все блоки с тегом "Caramel" через CollectionService.
	2. Когда персонаж игрока касается горячей или липкой карамели, скрипт находит его гуманоида.
	3. Здоровье гуманоида мгновенно обнуляется (Health = 0), сбрасывая игрока на последний чекпоинт.
	4. Используется защита (debounce), чтобы избежать избыточных вызовов при многократном касании.
	5. Слушатели событий аккуратно отключаются при удалении блока из игры.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

-- Настройки карамельной ловушки
local CARAMEL_TAG = "Caramel"           -- Тег для смертельных блоков карамели
local COOLDOWN_TIME = 0.5               -- Минимальный интервал (в секундах) между срабатываниями на персонажа

-- Таблица для отслеживания времени последнего срабатывания на каждого персонажа
local lastTriggerTime: { [Model]: number } = {}

-- Настройка одного карамельного блока
local function setupCaramel(part: Instance)
	-- Ловушкой может быть только физический блок (BasePart)
	if not part:IsA("BasePart") then
		return
	end

	-- Подключаем обработчик касания блока
	local connection = part.Touched:Connect(function(otherPart: BasePart)
		-- Определяем модель персонажа, коснувшегося карамели
		local character = otherPart.Parent
		if not character or not character:IsA("Model") then
			return
		end

		-- Ищем гуманоида — компонент здоровья и движения персонажа
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return -- Если это не персонаж или персонаж уже сброшен, ничего не делаем
		end

		-- Защита от спама (Debounce):
		-- Проверяем, не наступал ли персонаж на ловушку только что
		local currentTime = os.clock()
		local lastTime = lastTriggerTime[character] or 0

		if currentTime - lastTime < COOLDOWN_TIME then
			return
		end

		-- Фиксируем время срабатывания
		lastTriggerTime[character] = currentTime

		-- Мгновенно обнуляем здоровье, вызывая стандартный респавн персонажа
		humanoid.Health = 0
	end)

	-- Очистка памяти: отключаем слушатель Touched при удалении блока из игры
	part.Destroying:Connect(function()
		connection:Disconnect()
	end)
end

-- 1. Подключаем все карамельные блоки, уже размещенные на карте
for _, instance in CollectionService:GetTagged(CARAMEL_TAG) do
	task.spawn(setupCaramel, instance)
end

-- 2. Отслеживаем добавление новых блоков карамели во время игры
CollectionService:GetInstanceAddedSignal(CARAMEL_TAG):Connect(setupCaramel)

-- Очищаем записи из таблицы debounce, когда игрок покидает игру
Players.PlayerRemoving:Connect(function(player)
	local character = player.Character
	if character then
		lastTriggerTime[character] = nil
	end
end)
