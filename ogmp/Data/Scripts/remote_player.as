#include "aschar.as"
#include "situationawareness.as"

float grab_key_time;
bool delay_jump;
string MPUsername = "";
int username_billboard = -1;

bool MPWantsToCrouch = false;
bool MPWantsToJump = false;
bool MPWantsToAttack = false;
bool MPWantsToGrab = false;
bool MPWantsToItem = false;
bool MPWantsToDrop = false;
bool MPWantsToRoll = false;
bool MPWantsToJumpOffWall = false;
bool MPActiveBlock = false;
bool MPCutThroat = false;
int MPState = _movement_state;
int MPBloodDelay = 0;
int MPRagdollType = 0;
int MPKnockedOut = _awake;
float MPRollRecoveryTime = 1.0f;
float MPRecoveryTime = 1.0f;
float MPBloodAmount = 10.0f;
float MPPermanentHealth = 1.0f;
float MPTempHealth = 1.0f;
float MPBlockHealth = 1.0f;
float MPBloodHealth = 1.0f;
float MPBloodDamage = 0.0f;

float dir_z = 0.0f;
float dir_x = 0.0f;
float MPPositionX = 0.0f;
float MPPositionY = 0.0f;
float MPPositionZ = 0.0f;

enum PathFindType {_pft_nav_mesh, _pft_climb, _pft_drop, _pft_jump};
PathFindType path_find_type = _pft_nav_mesh;

Situation situation;

int IsUnaware() {
    return 0;
}

enum DropKeyState {_dks_nothing, _dks_pick_up, _dks_drop, _dks_throw};
DropKeyState drop_key_state = _dks_nothing;

enum ItemKeyState {_iks_nothing, _iks_sheathe, _iks_unsheathe};
ItemKeyState item_key_state = _iks_nothing;

void AIMovementObjectDeleted(int id) {
}

string GetIdleOverride(){
    return "";
}

float last_noticed_time;

void DrawStealthDebug() {
}

bool DeflectWeapon() {
    return active_blocking;
}

int IsAggro() {
    return 1;
}

void SetCharacterPosition(){
    if(MPPositionX != 0.0f){
        this_mo.position = vec3(MPPositionX, MPPositionY, MPPositionZ);
    }
}

void KeepVariablesSynced(){
    if(cut_throat != MPCutThroat){
        cut_throat = MPCutThroat;
    }
    if(knocked_out != MPKnockedOut){
        Print("Set knocked out! " + MPKnockedOut + "\n");
        SetKnockedOut(MPKnockedOut);
        SetCharacterPosition();
    }
    /*if(state != MPState){
        state = MPState;
    }*/
    if(blood_delay != MPBloodDelay){
        blood_delay = MPBloodDelay;
    }
    if(ragdoll_type != MPRagdollType){
        ragdoll_type = MPRagdollType;
    }
    if(roll_recovery_time != MPRollRecoveryTime){
        roll_recovery_time = MPRollRecoveryTime;
    }
    if(recovery_time != MPRecoveryTime){
        recovery_time = MPRecoveryTime;
    }
    if(blood_amount != MPBloodAmount){
        blood_amount = MPBloodAmount;
    }
    if(permanent_health != MPPermanentHealth){
        permanent_health = MPPermanentHealth;
    }
    if(temp_health != MPTempHealth){
        temp_health = MPTempHealth;
    }
    if(block_health != MPBlockHealth){
        block_health = MPBlockHealth;
    }
    if(blood_health != MPBloodHealth){
        blood_health = MPBloodHealth;
    }
    if(blood_damage != MPBloodDamage){
        blood_damage = MPBloodDamage;
    }
}

void UpdateBrain(const Timestep &in ts){
    KeepVariablesSynced();
    startled = false;
    if(MPWantsToGrab){
        grab_key_time += ts.step();
    } else {
        grab_key_time = 0.0f;
    }

    if(time > last_noticed_time + 0.2f){
        array<int> characters;
        GetVisibleCharacters(0, characters);
        for(uint i=0; i<characters.size(); ++i){
            situation.Notice(characters[i]);
        }
        last_noticed_time = time;
    }

    force_look_target_id = situation.GetForceLookTarget();

    if(!MPWantsToDrop){
        drop_key_state = _dks_nothing;
    } else if (drop_key_state == _dks_nothing){
        if((weapon_slots[primary_weapon_slot] == -1 || (weapon_slots[secondary_weapon_slot] == -1 && duck_amount < 0.5f)) &&
            GetNearestPickupableWeapon(this_mo.position, _pick_up_range) != -1)
        {
            drop_key_state = _dks_pick_up;
        } else {
            if(MPWantsToCrouch &&
               duck_amount > 0.5f &&
               on_ground &&
               !flip_info.IsFlipping() &&
               GetThrowTarget() == -1)
            {
                drop_key_state = _dks_drop;
            } else {
                drop_key_state = _dks_throw;
            }
        }
    }

    if(!MPWantsToItem){
        item_key_state = _iks_nothing;
    } else if (item_key_state == _iks_nothing){
        if(weapon_slots[primary_weapon_slot] == -1 ){
            item_key_state = _iks_unsheathe;
        } else {//if(held_weapon != -1 && sheathed_weapon == -1){
            item_key_state = _iks_sheathe;
        }
    }

    if(delay_jump && !GetInputDown(this_mo.controller_id, "jump")){
        delay_jump = false;
    }
	if(MPUsername != ""){
		UpdatePlayerUsernameBillboard();
	}
}

void UpdatePlayerUsernameBillboard(){
	vec3 draw_offset = vec3(0.0f, 1.25f, 0.0f);
	if(username_billboard != -1){
		DebugDrawRemove(username_billboard);
	}
	username_billboard = DebugDrawText(this_mo.position + draw_offset, MPUsername, 50.0f, true, _persistent);
}

void MPRemoveBillboard(){
	if(username_billboard != -1){
		DebugDrawRemove(username_billboard);
	}
}

void AIEndAttack(){

}

vec3 GetTargetJumpVelocity() {
    return vec3(0.0f);
}

bool TargetedJump() {
    return false;
}

bool IsAware(){
    return true;
}

void ResetMind() {
    situation.clear();
}

int IsIdle() {
    return 0;
}

void HandleAIEvent(AIEvent event){
    if(event == _climbed_up){
        delay_jump = true;
    }
}

void MindReceiveMessage(string msg){
}

bool WantsToCrouch() {
    return MPWantsToCrouch;
}

bool WantsToRoll() {
    return MPWantsToRoll;
}

bool WantsToJump() {
	return MPWantsToJump;
}

bool WantsToAttack() {
    return MPWantsToAttack;
}

bool WantsToRollFromRagdoll(){
    return MPWantsToRoll;
}

bool ActiveDodging(int attacker_id) {
    bool knife_attack = false;
    MovementObject@ char = ReadCharacterID(attacker_id);
    int enemy_primary_weapon_id = GetCharPrimaryWeapon(char);
    if(enemy_primary_weapon_id != -1){
        ItemObject@ weap = ReadItemID(enemy_primary_weapon_id);
        if(weap.GetLabel() == "knife"){
            knife_attack = true;
        }
    }
    if(attack_getter2.GetFleshUnblockable() == 1 && knife_attack){
        return active_dodge_time > time - 0.4f; // Player gets bonus to dodge vs knife attacks
    } else {
        return active_dodge_time > time - 0.2f;
    }
}

bool ActiveBlocking() {
    return MPActiveBlock;
}

bool WantsToFlip() {
    return MPWantsToRoll;
}

bool WantsToGrabLedge() {
    return MPWantsToGrab;
}

bool WantsToThrowEnemy() {
    return grab_key_time > 0.2f;
}

void Startle() {

}

bool WantsToDragBody() {
    return MPWantsToGrab;
}

bool WantsToPickUpItem() {
    return MPWantsToGrab;
}

bool WantsToDropItem() {
    return drop_key_state == _dks_drop;
}

bool WantsToThrowItem() {
    return drop_key_state == _dks_throw;
}

bool WantsToThroatCut() {
    return MPWantsToAttack;
}

bool WantsToSheatheItem() {
    return item_key_state == _iks_sheathe;
}

bool WantsToUnSheatheItem(int &out src) {
    if(item_key_state != _iks_unsheathe){
        return false;
    }
    src = -1;
    if(weapon_slots[_sheathed_right] != -1){
        src = _sheathed_right;
    } else if(weapon_slots[_sheathed_left] != -1){
        src = _sheathed_left;
    }
    return true;
}


bool WantsToStartActiveBlock(const Timestep &in ts){
    return MPActiveBlock;
}

bool WantsToFeint(){
    return MPWantsToGrab;
}

bool WantsToCounterThrow(){
    return MPWantsToGrab;
}

bool WantsToJumpOffWall() {
    return MPWantsToJumpOffWall;
}

bool WantsToFlipOffWall() {
    return MPWantsToRoll;
}

bool WantsToAccelerateJump() {
    return MPWantsToJump;
}

vec3 GetDodgeDirection() {
    return GetTargetVelocity();
}

bool WantsToDodge(const Timestep &in ts) {
    vec3 targ_vel = GetTargetVelocity();
    bool movement_key_down = false;
    if(length_squared(targ_vel) > 0.1f){
        movement_key_down = true;
    }
    return movement_key_down;
}

bool WantsToCancelAnimation() {
    return MPWantsToJump ||
           MPWantsToCrouch ||
           MPWantsToGrab ||
           MPWantsToAttack ||
           GetInputDown(this_mo.controller_id, "move_up") ||
           GetInputDown(this_mo.controller_id, "move_left") ||
           GetInputDown(this_mo.controller_id, "move_right") ||
           GetInputDown(this_mo.controller_id, "move_down");
}

// Converts the keyboard controls into a target velocity that is used for movement calculations in aschar.as and aircontrol.as.
vec3 GetTargetVelocity() {
    vec3 target_velocity = vec3(dir_x, 0.0f, dir_z);

    if(length_squared(target_velocity)>1){
        target_velocity = normalize(target_velocity);
    }

    if(trying_to_get_weapon > 0){
        target_velocity = get_weapon_dir;
    }

    return target_velocity;
}

// Called from aschar.as, bool front tells if the character is standing still. Only characters that are standing still may perform a front kick.
void ChooseAttack(bool front, string& out attack_str) {
    attack_str = "";
    if(on_ground){
        if(!WantsToCrouch()){
            if(front){
                attack_str = "stationary";
            } else {
                attack_str = "moving";
            }
        } else {
            attack_str = "low";
        }
    } else {
        attack_str = "air";
    }
}

WalkDir WantsToWalkBackwards() {
    return FORWARDS;
}

bool WantsReadyStance() {
    return true;
}

int CombatSong() {
    return situation.PlayCombatSong()?1:0;
}

int IsAggressive() {
    return 0;
}

int GetLeftFootPlanted(){
    if(foot[0].progress == 1.0f){
        return 1;
    }else{
        return 0;
    }
}

int GetRightFootPlanted(){
    Print("progress " + foot[1].progress + "\n");
    if(foot[1].progress >= 1.0f){
        return 1;
    }else{
        return 0;
    }
}
bool StuckToNavMesh() {
    if(path_find_type == _pft_nav_mesh){
        vec3 nav_pos = GetNavPointPos(this_mo.position);
        if(abs(nav_pos[1] - this_mo.position[1]) > 1.0){
            return false;
        }
        nav_pos[1] = this_mo.position[1];
        if(distance(nav_pos, this_mo.position) < 0.1){
            return true;
        } else {
            return false;
        }
    } else {
        return false;
    }
}
