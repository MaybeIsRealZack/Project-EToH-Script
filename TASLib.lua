local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local TASController = {}
TASController.__index = TASController

local STATE = {
	IDLE = "IDLE",
	RECORDING = "RECORDING",
	PLAYING = "PLAYING",
	PAUSED = "PAUSED",
}
TASController.STATE = STATE

function TASController.new()
	local self = setmetatable({}, TASController)

	self._state = STATE.IDLE
	self._frames = {}
	self._frameIndex = 0
	self._connection = nil

	self._currentMove = Vector3.new()
	self._currentJump = false

	self.OnStateChanged = nil
	self.OnFrameStepped = nil

	self:_bindInput()

	return self
end

function TASController:_bindInput()
	local moveKeys = {
		[Enum.KeyCode.W] = Vector3.new(0, 0, -1),
		[Enum.KeyCode.S] = Vector3.new(0, 0, 1),
		[Enum.KeyCode.A] = Vector3.new(-1, 0, 0),
		[Enum.KeyCode.D] = Vector3.new(1, 0, 0),
	}
	local pressed = {}

	local function recalcMove()
		local total = Vector3.new()
		for key, dir in pairs(moveKeys) do
			if pressed[key] then
				total += dir
			end
		end
		if total.Magnitude > 0 then
			total = total.Unit
		end
		self._currentMove = total
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if moveKeys[input.KeyCode] then
			pressed[input.KeyCode] = true
			recalcMove()
		elseif input.KeyCode == Enum.KeyCode.Space then
			self._currentJump = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if moveKeys[input.KeyCode] then
			pressed[input.KeyCode] = false
			recalcMove()
		elseif input.KeyCode == Enum.KeyCode.Space then
			self._currentJump = false
		end
	end)
end

function TASController:_setState(newState)
	self._state = newState
	if self.OnStateChanged then
		self.OnStateChanged(newState)
	end
end

function TASController:GetState()
	return self._state
end

function TASController:StartRecording()
	if self._state == STATE.RECORDING then return end
	self._frames = {}
	self._frameIndex = 0
	self:_setState(STATE.RECORDING)

	if self._connection then
		self._connection:Disconnect()
	end

	self._connection = RunService.Heartbeat:Connect(function(dt)
		self._frameIndex += 1
		self._frames[self._frameIndex] = {
			dt = dt,
			mx = self._currentMove.X,
			my = self._currentMove.Y,
			mz = self._currentMove.Z,
			jump = self._currentJump,
		}
	end)
end

function TASController:StopRecording()
	if self._state ~= STATE.RECORDING then return end
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	self:_setState(STATE.IDLE)
end

local function getHumanoid()
	local char = player.Character or player.CharacterAdded:Wait()
	return char:WaitForChild("Humanoid")
end

function TASController:_applyFrame(frame)
	local humanoid = getHumanoid()
	local moveVector = Vector3.new(frame.mx, frame.my, frame.mz)
	humanoid:Move(moveVector)
	if frame.jump then
		humanoid.Jump = true
	end
end

function TASController:StartPlayback()
	if #self._frames == 0 then
		warn("[TASController] 沒有可播放的錄製資料")
		return
	end
	if self._state == STATE.IDLE then
		self._frameIndex = 0
	end
	self:_setState(STATE.PLAYING)

	if self._connection then
		self._connection:Disconnect()
	end

	self._connection = RunService.Heartbeat:Connect(function()
		if self._state ~= STATE.PLAYING then return end
		self._frameIndex += 1
		local frame = self._frames[self._frameIndex]
		if not frame then
			self:StopPlayback()
			return
		end
		self:_applyFrame(frame)
		if self.OnFrameStepped then
			self.OnFrameStepped(self._frameIndex, #self._frames)
		end
	end)
end

function TASController:PausePlayback()
	if self._state ~= STATE.PLAYING then return end
	self:_setState(STATE.PAUSED)
end

function TASController:ResumePlayback()
	if self._state ~= STATE.PAUSED then return end
	self:_setState(STATE.PLAYING)
end

function TASController:StopPlayback()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	self:_setState(STATE.IDLE)
end

function TASController:StepFrame()
	if self._state ~= STATE.PAUSED then
		warn("[TASController] StepFrame 只能在 PAUSED 狀態下呼叫,請先 PausePlayback()")
		return false
	end
	self._frameIndex += 1
	local frame = self._frames[self._frameIndex]
	if not frame then
		warn("[TASController] 已經是最後一幀")
		self._frameIndex -= 1
		return false
	end
	self:_applyFrame(frame)
	if self.OnFrameStepped then
		self.OnFrameStepped(self._frameIndex, #self._frames)
	end
	return true
end

function TASController:StepBack()
	if self._state ~= STATE.PAUSED then
		warn("[TASController] StepBack 只能在 PAUSED 狀態下呼叫")
		return false
	end
	if self._frameIndex <= 0 then return false end
	self._frameIndex -= 1
	if self.OnFrameStepped then
		self.OnFrameStepped(self._frameIndex, #self._frames)
	end
	return true
end

function TASController:GetFrameIndex()
	return self._frameIndex
end

function TASController:GetTotalFrames()
	return #self._frames
end

function TASController:Export()
	return HttpService:JSONEncode(self._frames)
end

function TASController:Import(jsonString)
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(jsonString)
	end)
	if not ok then
		warn("[TASController] Import 失敗,JSON 格式錯誤")
		return false
	end
	self._frames = decoded
	self._frameIndex = 0
	self:_setState(STATE.IDLE)
	return true
end

return TASController
