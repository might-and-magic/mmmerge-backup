local asmpatch, hook = mem.asmpatch, mem.hook

local function ExtendEvtVars()
	------ evt.Cmp ------

	-- Add NPCs support
	local NewCode = asmpatch(0x4477F7, [[
	cmp eax, 0xEA
	jnz @none
	nop
	nop
	nop
	nop
	nop
	jmp absolute 0x447AC8
	@none:
	sub eax, 0xE7
	]])

	hook(NewCode + 7, function(d)
		local npc_id = d.ebx
		d.edi = NPCFollowers.NPCInGroup(npc_id) and npc_id or 0
	end)

	------ evt.Set ------

	-- Add NPCs support
	NewCode = asmpatch(0x44824A, [[
	cmp eax, 0xEA
	jnz @none
	mov ecx, dword ptr [ebp+0xC]
	nop
	nop
	nop
	nop
	nop
	jmp absolute 0x448488
	@none:
	cmp eax, 0xE9]])

	hook(NewCode + 10, function(d)
		local result = NPCFollowers.Add(d.ecx)
		if not result then
			-- Log error message
		end
	end)

	------ evt.Add ------

	-- Add ReputationIs and NPCs support
	NewCode = asmpatch(0x448B80, [[
	cmp eax, 0xEA
	jnz @first
	mov ecx, dword ptr [ebp+0xC]
	nop
	nop
	nop
	nop
	nop
	jmp absolute 0x448E29
	@first:
	cmp eax, 0xEB
	jnz @none
	neg dword [ebp+0xC]
	jmp absolute 0x448CCF
	@none:
	cmp eax, 0xE9]])

	hook(NewCode + 10, function(d)
		local result = NPCFollowers.Add(d.ecx)
		if not result then
			-- Log error message
		end
	end)

	-- Reputation lower bound check
	asmpatch(0x448CF2, [[
	jg absolute 0x448CF8
	neg ecx
	cmp edx, ecx
	jge absolute 0x448E29
	mov [eax+8], ecx
	jmp absolute 0x448E29]])

	------ evt.Subtract ------

	-- Add ReputationIs and NPCs support
	NewCode = asmpatch(0x44943E, [[
	cmp eax, 0xEA
	jnz @first
	mov ecx, dword ptr [ebp+0xC]
	nop
	nop
	nop
	nop
	nop
	jmp absolute 0x4490C3
	@first:
	cmp eax, 0xEB
	jnz @none
	neg dword [ebp+0xC]
	jmp absolute 0x4494DE
	@none:
	cmp eax, 0xE9]])

	hook(NewCode + 10, function(d)
		local result = NPCFollowers.Remove(d.ecx)
		if not result then
			-- Log error message
		end
	end)

	-- Reputation upper bound check
	asmpatch(0x449501, [[
	jl absolute 0x449507
	neg ecx
	cmp edx, ecx
	jle absolute 0x4490C3
	mov [eax+8], ecx
	jmp absolute 0x4490C3]])
end

function events.GameInitialized1()
	ExtendEvtVars()
end
