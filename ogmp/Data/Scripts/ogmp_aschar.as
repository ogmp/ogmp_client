int ragdoll_counter = 0;
float dir_x = 0.0f;
float dir_z = 0.0f;

bool MPWantsToCrouch = false;
bool MPWantsToJump = false;
bool MPWantsToAttack = false;
bool MPWantsToGrab = false;
bool MPWantsToItem = false;
bool MPWantsToDrop = false;
bool MPWantsToRoll = false;
bool MPWantsToJumpOffWall = false;
bool MPActiveBlock = false;
bool MPIsConnected = false;

void UpdateOGMP() {
	if(this_mo.controlled) {
		MPWantsToCrouch = GetInputDown(this_mo.controller_id, "crouch");
		MPWantsToJump = GetInputDown(this_mo.controller_id, "jump");
		MPWantsToAttack = GetInputDown(this_mo.controller_id, "attack");
		MPWantsToGrab = GetInputDown(this_mo.controller_id, "grab");
		MPWantsToItem = GetInputDown(this_mo.controller_id, "item");
		MPWantsToDrop = GetInputDown(this_mo.controller_id, "drop");
		if(GetInputPressed(this_mo.controller_id, "crouch")) {
			MPWantsToRoll = true;
		}
		if(GetInputPressed(this_mo.controller_id, "jump")) {
			MPWantsToJumpOffWall = true;
		}
		if(GetInputPressed(this_mo.controller_id, "grab")) {
			MPActiveBlock = true;
		}
	}
}
