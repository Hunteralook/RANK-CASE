if not CLIENT then return end

--[[
    Клиентский кейс с визуальной рулеткой.

    Запуск:
      1. Написать !case в чат.
      2. Или выполнить rank_case в клиентской консоли.

    Важно: результат выбирается на клиенте и не выдаёт настоящую группу.
]]

local CONFIG = {
    chatCommand = "!case",
    consoleCommand = "rank_case",
    spinDuration = 5,
    totalCards = 52,
    winningCard = 44
}

local ROLES = {
    {
        name = "user",
        chance = 70,
        color = Color(70, 190, 105)
    },
    {
        name = "gamemaster",
        chance = 25,
        color = Color(75, 145, 255)
    },
    {
        name = "gay_s",
        chance = 5,
        color = Color(225, 75, 180)
    }
}

local activeFrame

local function CreateFonts()
    local scale = math.Clamp(ScrH() / 1080, 0.75, 1.2)

    surface.CreateFont("RankCase_Title", {
        font = "Roboto",
        size = math.floor(30 * scale),
        weight = 900,
        extended = true
    })

    surface.CreateFont("RankCase_Card", {
        font = "Roboto",
        size = math.floor(24 * scale),
        weight = 800,
        extended = true
    })

    surface.CreateFont("RankCase_Small", {
        font = "Roboto",
        size = math.floor(18 * scale),
        weight = 500,
        extended = true
    })

    surface.CreateFont("RankCase_Close", {
        font = "Roboto",
        size = math.floor(28 * scale),
        weight = 700,
        extended = true
    })
end

CreateFonts()
hook.Add("OnScreenSizeChanged", "RankCase_RecreateFonts", CreateFonts)

local function RollRole()
    local roll = math.random(1, 100)

    if roll <= 70 then
        return ROLES[1]
    elseif roll <= 95 then
        return ROLES[2]
    end

    return ROLES[3]
end

local function EaseOutQuart(value)
    return 1 - (1 - value) ^ 4
end

local function OpenRankCase()
    if IsValid(activeFrame) then
        activeFrame:MoveToFront()
        return
    end

    local winner = RollRole()
    local cards = {}

    for index = 1, CONFIG.totalCards do
        cards[index] = RollRole()
    end

    -- Карточка под центральной стрелкой всегда совпадает с выбранным результатом.
    cards[CONFIG.winningCard] = winner

    local frameWidth = math.Clamp(ScrW() - 80, 720, 1000)
    local frameHeight = 340

    local frame = vgui.Create("DFrame")
    activeFrame = frame

    frame:SetSize(frameWidth, frameHeight)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(false)
    frame:SetSizable(false)
    frame:ShowCloseButton(false)
    frame:SetDeleteOnClose(true)
    frame:MakePopup()

    frame.openedAt = SysTime()
    frame.revealed = false

    frame.Paint = function(self, width, height)
        Derma_DrawBackgroundBlur(self, self.openedAt)

        draw.RoundedBox(16, 0, 0, width, height, Color(16, 19, 27, 250))
        draw.RoundedBox(16, 2, 2, width - 4, height - 4, Color(24, 28, 39, 250))

        draw.SimpleText(
            "КЕЙС С РОЛЯМИ",
            "RankCase_Title",
            width / 2,
            34,
            Color(245, 247, 255),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )

        if self.revealed then
            draw.SimpleText(
                "Мне выпал: " .. winner.name,
                "RankCase_Card",
                width / 2,
                height - 42,
                winner.color,
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )
        else
            draw.SimpleText(
                "Кейс открывается...",
                "RankCase_Small",
                width / 2,
                height - 42,
                Color(175, 181, 197),
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )
        end
    end

    frame.OnRemove = function(self)
        if activeFrame == self then
            activeFrame = nil
        end
    end

    local closeButton = vgui.Create("DButton", frame)
    closeButton:SetSize(42, 36)
    closeButton:SetPos(frameWidth - 52, 10)
    closeButton:SetText("")
    closeButton:SetEnabled(false)
    closeButton:SetAlpha(70)

    closeButton.Paint = function(self, width, height)
        local background = self:IsHovered()
            and Color(205, 65, 75, 230)
            or Color(48, 53, 67, 230)

        draw.RoundedBox(8, 0, 0, width, height, background)
        draw.SimpleText(
            "×",
            "RankCase_Close",
            width / 2,
            height / 2 - 1,
            color_white,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end

    closeButton.DoClick = function()
        frame:Close()
    end

    local reel = vgui.Create("DPanel", frame)
    reel:SetPos(20, 78)
    reel:SetSize(frameWidth - 40, 190)

    reel.cardWidth = 180
    reel.cardGap = 12
    reel.step = reel.cardWidth + reel.cardGap
    reel.startOffset = reel:GetWide() / 2 - reel.cardWidth / 2

    -- Небольшое смещение делает остановку менее механической,
    -- но стрелка всё равно остаётся внутри выигрышной карточки.
    local landingJitter = math.Rand(-reel.cardWidth * 0.27, reel.cardWidth * 0.27)
    reel.endOffset = reel:GetWide() / 2
        - ((CONFIG.winningCard - 1) * reel.step + reel.cardWidth / 2)
        + landingJitter

    reel.offset = reel.startOffset
    reel.startedAt = SysTime()
    reel.lastTickCard = 1
    reel.nextTickSound = 0
    reel.finished = false

    reel.Paint = function(self, width, height)
        draw.RoundedBox(12, 0, 0, width, height, Color(10, 12, 18, 255))

        for index, role in ipairs(cards) do
            local x = self.offset + (index - 1) * self.step

            if x + self.cardWidth >= 0 and x <= width then
                local cardY = 18
                local cardHeight = height - 36
                local isWinner = self.finished and index == CONFIG.winningCard
                local background = Color(
                    math.floor(role.color.r * 0.22),
                    math.floor(role.color.g * 0.22),
                    math.floor(role.color.b * 0.22),
                    255
                )

                if isWinner then
                    draw.RoundedBox(12, x - 4, cardY - 4, self.cardWidth + 8, cardHeight + 8, Color(role.color.r, role.color.g, role.color.b, 70))
                end

                draw.RoundedBox(10, x, cardY, self.cardWidth, cardHeight, background)
                draw.RoundedBox(10, x + 3, cardY + 3, self.cardWidth - 6, 7, role.color)

                draw.SimpleText(
                    role.name,
                    "RankCase_Card",
                    x + self.cardWidth / 2,
                    cardY + cardHeight / 2 - 12,
                    Color(245, 247, 255),
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )

                draw.SimpleText(
                    role.chance .. "%",
                    "RankCase_Small",
                    x + self.cardWidth / 2,
                    cardY + cardHeight / 2 + 24,
                    role.color,
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
            end
        end

        -- Затемнение краёв рулетки.
        surface.SetDrawColor(8, 10, 15, 185)
        surface.DrawRect(0, 0, 54, height)
        surface.DrawRect(width - 54, 0, 54, height)

        -- Центральная стрелка сверху и снизу.
        draw.NoTexture()
        surface.SetDrawColor(255, 198, 74, 255)
        surface.DrawPoly({
            {x = width / 2 - 13, y = 0},
            {x = width / 2 + 13, y = 0},
            {x = width / 2, y = 19}
        })
        surface.DrawPoly({
            {x = width / 2 - 13, y = height},
            {x = width / 2 + 13, y = height},
            {x = width / 2, y = height - 19}
        })
    end

    reel.Think = function(self)
        if self.finished then return end

        local progress = math.Clamp(
            (SysTime() - self.startedAt) / CONFIG.spinDuration,
            0,
            1
        )

        self.offset = Lerp(
            EaseOutQuart(progress),
            self.startOffset,
            self.endOffset
        )

        local distanceToCenter = self:GetWide() / 2 - self.offset - self.cardWidth / 2
        local centeredCard = math.Clamp(
            math.floor(distanceToCenter / self.step + 0.5) + 1,
            1,
            #cards
        )

        if centeredCard ~= self.lastTickCard and SysTime() >= self.nextTickSound then
            self.lastTickCard = centeredCard
            self.nextTickSound = SysTime() + 0.035
            surface.PlaySound("buttons/lightswitch2.wav")
        end

        if progress < 1 then return end

        self.offset = self.endOffset
        self.finished = true
        frame.revealed = true

        closeButton:SetEnabled(true)
        closeButton:SetAlpha(255)

        surface.PlaySound("garrysmod/save_load1.wav")
        RunConsoleCommand("say", "Мне выпал: " .. winner.name)
    end
end

hook.Add("OnPlayerChat", "RankCase_OpenFromChat", function(ply, text)
    if ply ~= LocalPlayer() then return end
    if string.lower(string.Trim(text)) ~= CONFIG.chatCommand then return end

    OpenRankCase()

    -- Скрывает !case только у игрока, открывшего кейс.
    -- Другие игроки уже получили сообщение от сервера.
    return true
end)

concommand.Remove(CONFIG.consoleCommand)
concommand.Add(CONFIG.consoleCommand, OpenRankCase)

print("[RankCase] удалённый код кейса загружен")
