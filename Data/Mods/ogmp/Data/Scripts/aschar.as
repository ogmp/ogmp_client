#include "interpdirection.as"
#include "aschar_aux.as"
#include "aircontrols.as"
#include "ogmp_aschar.as"

enum WalkDir {WALK_BACKWARDS, STRAFE, FORWARDS};

AttackScriptGetter attack_getter;
AttackScriptGetter attack_getter2;

JumpInfo jump_info;
LedgeInfo ledge_info;

bool static_char = false;
bool left_handed = true;
bool dialogue_control = false;
vec3 dialogue_position;

const float QUIET_SOUND_AI = 2.0f;
const float LOUD_SOUND_AI = 5.0f;

enum AIEvent{_ragdolled, _activeblocked, _thrown, _choking, _jumped, _can_climb,
             _grabbed_ledge, _climbed_up, _damaged};

int head_choke_queue = -1;

vec3 push_velocity; // Accumulates collision response between characters

float block_stunned = 0.0f;
int block_stunned_by_id = -1;

// For sliding on ice
vec3 old_slide_vel;
vec3 new_slide_vel;
float friction = 1.0f;

// Throat cut variables
uint32 last_blood_particle_id = 0;
int blood_delay = 0;
bool cut_throat = false;
bool cut_torso = false;
const float _max_blood_amount = 10.0f;
float blood_amount = _max_blood_amount;
const float _spurt_frequency = 7.0f;
float spurt_sound_delay = 0.0f;
const float _spurt_delay_amount = 6.283185f/_spurt_frequency;

const float _body_part_drag_dist = 0.2f;
bool in_animation = false;
float combat_stance_time = -10.0f;

// Knife combat variables
bool backslash = false;
float last_knife_time = 0.0f;
int knife_layer_id = -1;
int throw_knife_layer_id = -1;

float plant_rustle_delay = 0.0f;
float in_plant = 0.0f;

float blood_damage = 0.0f; // How much blood damage remains to be dealt
float blood_health = 1.0f; // How much blood remaining before passing out
float block_health = 1.0f; // How strong is auto-block? Similar to ssb shield
float temp_health = 1.0f; // Remaining regenerating health until knocked out
float permanent_health = 1.0f; // Remaining non-regenerating health until killed

bool test_talking = false;
float test_talking_amount = 0.0f;

int knocked_out = _awake;
float knocked_out_time = 0.0f;

float speak_sound_delay = 0.0f;
vec3 dialogue_torso_target;
float dialogue_torso_control;
vec3 dialogue_head_target;
float dialogue_head_control;

// Body bob offset so that characters don't sway in sync
float body_bob_freq = 0.0f;
float body_bob_time_offset;

// Parameter values
float p_aggression;
float p_ground_aggression;
float p_damage_multiplier;
float p_block_skill;
float p_block_followup;
float p_attack_speed_mult;
float p_speed_mult;
float p_attack_damage_mult;
float p_attack_knockback_mult;
float p_fat;
float p_muscle;
float p_ear_size;
int p_lives;

const bool draw_skeleton_lines = false;

float roll_ik_fade = 0.0f;
float flip_ik_fade = 0.0f;

float offset_height = 0.0f;

const float _check_up = 1.0f;
const float _check_down = -1.0f;

bool idle_stance = false;
float idle_stance_amount = 0.0f;

const float _stance_move_threshold = 5.0f;

vec3 drag_target;

// States are used to differentiate between various widely different situations
const int _movement_state = 0; // character is moving on the ground
const int _ground_state = 1; // character has fallen down or is raising up, ATM ragdolls handle most of this
const int _attack_state = 2; // character is performing an attack
const int _hit_reaction_state = 3; // character was hit or dealt damage to and has to react to it in some manner
const int _ragdoll_state = 4; // character is falling in ragdoll mode
int state = _movement_state;

bool blinking = false;  // Currently in the middle of blinking?
float blink_progress = 0.0f; // Progress from 0.0 (pre-blink) to 1.0 (post-blink)
float blink_delay = 0.0f; // Time until next blink
float blink_amount = 0.0f; // How open eyes currently are
float blink_mult = 1.0f; // How open eyes want to be (when not blinking)

vec3 target_tilt(0.0f);
vec3 tilt(0.0f);

float stance_move_fade = 0.0f;
float stance_move_fade_val = 0.0f;
    
float head_look_opac;
float choke_look_time = 0.0f;

int force_look_target_id = -1;
vec3 random_look_dir;
float random_look_delay = 0.0f;
LookTarget look_target;

vec3 head_vel;
float layer_attacking_fade = 0.0f;
float layer_throwing_fade = 0.0f;

vec3 eye_dir; // Direction eyes are looking
vec3 target_eye_dir; // Direction eyes want to look
float eye_delay = 0.0f; // How much time until the next eye dir adjustment
vec3 dialogue_eye_dir;
string dialogue_anim;

vec3 dodge_dir;
bool active_dodging = false;
bool active_blocking = false;
int active_block_flinch_layer = -1;

float active_block_duration = 0.0f; // How much longer can the active block last
float active_block_recharge = 0.0f; // How long until the active block recharges

float active_dodge_duration = 0.0f; // How much longer can the active dodge last
float active_dodge_recharge = 0.0f; // How long until the active dodge recharges

float ragdoll_time; // How long spent in ragdoll mode this time
bool frozen; // Dead or unconscious ragdoll no longer needs to be simulated
bool no_freeze = false; // Freezing is disabled, e.g. for active ragdolls
float injured_mouth_open; // How open mouth is during injured writhe

float ragdoll_static_time; // How long ragdoll has been stationary

const float _auto_wake_vel_threshold = 20.0f;

float recovery_time;
float roll_recovery_time;

const int _RGDL_NO_TYPE = 0;
const int _RGDL_FALL = 1;
const int _RGDL_LIMP = 2;
const int _RGDL_INJURED = 3;
const int _RGDL_ANIMATION = 4;

int ragdoll_type;
int ragdoll_layer_fetal;
int ragdoll_layer_catchfallfront;
float ragdoll_limp_stun;

const int _miss = 0;
const int _going_to_block = 1;
const int _hit = 2;
const int _block_impact = 3;
const int _invalid = 4;

bool startled = false;
const float drop_weapon_probability = 0.2f;

// whether the character is in the ground or in the air, and how long time has passed since the status changed. 
bool on_ground = false;

const float _duck_speed_mult = 0.5f;

const float _ground_normal_y_threshold = 0.5f;
const float _leg_sphere_size = 0.45f; // affects the size of a sphere collider used for leg collisions
const float _bumper_size = 0.5f;

const float _base_run_speed = 8.0f; // used to calculate movement and jump velocities, change this instead of max_speed
const float _base_true_max_speed = 12.0f; // speed can never exceed this amount
float run_speed = _base_run_speed;
float true_max_speed = _base_true_max_speed;
float max_speed = run_speed; // this is recalculated constantly because actual max speed is affected by slopes

const float _tilt_transition_vel = 8.0f;

vec3 ground_normal(0,1,0);

// feet are moving if character isn't standing still, defined by targetvelocity being larger than 0.0 in UpdateGroundMovementControls()
bool feet_moving = false;
float getting_up_time;

int run_phase = 1;

string hit_reaction_event;

bool attack_animation_set = false;
bool hit_reaction_anim_set = false;
bool hit_reaction_dodge = false;
bool hit_reaction_thrown = false;
int attacking_with_throw;

const float _attack_range = 1.5f;
const float _close_attack_range = 1.0f;
float range_extender = 0.0f;
float range_multiplier = 1.0f;

// running and movement
const float _run_threshold = 0.8f; // when character is moving faster than this, it runs
const float _walk_threshold = 0.6f; // when character is moving slower than this, it's idling
const float _walk_accel = 35.0f; // how fast characters accelerate when moving

const float _roll_speed = 2.0f;
const float _roll_accel = 50.0f;
const float _roll_ground_speed = 12.0f;
vec3 roll_direction;

vec3 flip_modifier_axis;
float flip_modifier_rotation;
vec3 tilt_modifier;

float leg_cannon_flip;

bool mirrored_stance = false;

vec3 old_vel;
vec3 last_col_pos;

float cancel_delay;

string curr_attack; 
int target_id = -1;
int attacked_by_id = -1;
int self_id;

enum WeaponSlot {
    _held_left=0,
    _held_right=1,
    _sheathed_left=2,
    _sheathed_right=3,
    _sheathed_left_sheathe=4,
    _sheathed_right_sheathe=5,
};

int primary_weapon_slot = _held_right;
int secondary_weapon_slot = _held_left;
const int _num_weap_slots = 6;
array<int> weapon_slots;

// Pre-jump happens after jump key is pressed and before the character gets upwards velocity. The time available for the jump animation that happens on the ground. 
bool pre_jump = false;
float pre_jump_time;

bool feinting;
bool can_feint;
float tether_dist;
vec3 tether_rel;

const int _TETHERED_FREE = 0;
const int _TETHERED_REARCHOKE = 1;
const int _TETHERED_REARCHOKED = 2;
const int _TETHERED_DRAGBODY = 3;
const int _TETHERED_DRAGGEDBODY = 4;
string drag_body_part;
int drag_body_part_id;
float drag_strength_mult;
const vec3 drag_offset(0.15f, 0.0f, 0.3f);
int tethered = _TETHERED_FREE;
int tether_id = -1;

const float _max_tether_height_diff = 0.2f;
bool executing = false;

vec3 accel_tilt;

enum IdleType{_stand, _active, _combat};
IdleType idle_type = _active;

const float vision_threshold = 40.0f;
const float vision_threshold_squared = vision_threshold*vision_threshold;

const uint16 _TC_ENEMY = (1<<0);
const uint16 _TC_CONSCIOUS = (1<<1);
const uint16 _TC_THROWABLE = (1<<2);
const uint16 _TC_NON_RAGDOLL = (1<<3);
const uint16 _TC_ALLY = (1<<4);
const uint16 _TC_IDLE = (1<<5);
const uint16 _TC_UNAWARE = (1<<7);
const uint16 _TC_RAGDOLL = (1<<8);
const uint16 _TC_UNCONSCIOUS = (1<<9);
const uint16 _TC_KNOWN = (1<<10);

const float offset = 0.05f;

const bool _draw_collision_spheres = false;

const float _shock_damage_threshold = 30.0f;
const float _shock_damage_multiplier = 0.1f;

const bool _draw_predict_path = true;
bool throw_anim;

enum PredictPathType {_ppt_drop, _ppt_climb, _ppt_none};
class PredictPathOutput {
    PredictPathType type;
    vec3 start_pos;
    vec3 end_pos;
    vec3 normal;
};

// the main timer of the script, used whenever anything has to know how much time has passed since something else happened.
float time = 0;

// The following variables and function affect the track decals foots make on the ground, when that feature is enabled
const float _smear_time_threshold = 0.3f;
float smear_sound_time = 0.0f;
float left_smear_time = 0.0f;
float right_smear_time = 0.0f;
float _dist_threshold = 0.1f;
vec3 left_decal_pos;
vec3 right_decal_pos;

float _base_launch_speed = 20.0f;
float _base_up_speed = 10.0f;

const float _get_weapon_time_limit = 0.4f;
float trying_to_get_weapon_time;
int trying_to_get_weapon = 0;
vec3 get_weapon_dir;
vec3 get_weapon_pos;
int pickup_layer = -1;
int pickup_layer_attempts = 0;
bool going_to_throw_item = false;
float going_to_throw_item_time;
int sheathe_layer_id = -1;

float _pick_up_range = 2.0f;

vec3 old_cam_pos;
float target_rotation = 0.0f;
float target_rotation2 = 0.0f;
float cam_rotation = 0.0f;
float cam_rotation2 = 0.0f; 
bool cam_rotation_set = false;
float cam_distance = 1.0f;
float auto_cam_override = 0.0f;

vec3 ragdoll_cam_pos;
vec3 cam_pos_offset;

const bool cam_input = true;
class AutoCam {
    vec3 chase_cam_pos;
    float target_side_weight;
    float target_weight;
    float angle;
    AutoCam() {
        target_side_weight = 0.5f;
        target_weight = 0.0f;
        angle = 0.2f;
    }
};
AutoCam autocam;
float shared_cam_elevation = 0.0f;
float target_shared_cam_elevation = 0.0f;
array<float> shared_cam_elevation_history;
float reset_no_collide;

bool stance_move = true;

class Foot {
    vec3 pos;
    vec3 old_pos;
    vec3 target_pos;
    float progress;
    bool planted;
    float height;
};

Foot[] foot;
bool use_foot_plants = false;
bool old_use_foot_plants = false;

int lives;

float duck_amount = 0.0f; // duck_amount is changed incrementally to animate crouching or standing up from a crouch
float target_duck_amount = 0.0f; // this is 1.0 when the character crouches down,  0.0 otherwise. Used in UpdateDuckAmount() 
float duck_vel = 0.0f;

float threat_amount = 0.0f;
float target_threat_amount = 0.0f;
float threat_vel = 0.0f;

float air_time = 0.0f;
float on_ground_time = 0.0f;

float attack_predictability = 0.0f;

float hit_reaction_time;

bool active_block_anim = false;

vec3 mov_start;

const int _wake_stand = 0;
const int _wake_flip = 1;
const int _wake_roll = 2;
const int _wake_fall = 3;
const int _wake_block_stand = 4;

vec3 wake_up_torso_up;
vec3 wake_up_torso_front;
float ragdoll_cam_recover_time = 0.0f;
float ragdoll_cam_recover_speed = 1.0f;

int count = 0;

enum ExecutionType {
	NO_EXECUTION = 0,
	STARTING_THROAT_CUT = 1,
	FINISHING_THROAT_CUT = 2
};
ExecutionType being_executed = NO_EXECUTION;

void ChokedOut(int target){
    head_choke_queue = target;
}

void ParryItem(int id){
    ItemObject@ io = ReadItemID(id);
    vec3 item_pos = io.GetPhysicsPosition();

    HandleWeaponWeaponCollision(id);

    vec3 char_to_item = io.GetPhysicsPosition() - this_mo.position;
    vec3 dir_char_to_item = normalize(char_to_item);
    vec3 vel = io.GetLinearVelocity();
    vel -= 1.2f * dot(vel, dir_char_to_item) * dir_char_to_item;
    //io.SetLinearVelocity(char_to_item * 5.0f);
    io.SetLinearVelocity(this_mo.velocity);
    io.SetSafe();
    float rotation_amount = 20.0f;
    io.SetAngularVelocity(vec3(RangedRandomFloat(-1.0f,1.0f),RangedRandomFloat(-1.0f,1.0f),RangedRandomFloat(-1.0f,1.0f)) * rotation_amount);
}

void CatchItem(int id){
    ItemObject@ io = ReadItemID(id);
    vec3 lin_vel = io.GetLinearVelocity();
    { // Apply force of item to character velocity
        vec3 force = (lin_vel - this_mo.velocity) * io.GetMass();
        float force_len = length(force);
        this_mo.velocity = force * 0.1f;
    }
    { // Rotate character to face in the opposite direction that the item is moving
        vec3 face_dir = lin_vel * -1.0f;
        face_dir.y = 0.0f;
        face_dir = normalize(face_dir);
        this_mo.SetRotationFromFacing(face_dir);
    }
    // Rotate character towards the position of the item
    vec3 flat_item_to_char = io.GetPhysicsPosition() - this_mo.position;
    flat_item_to_char.y = 0.0f;
    flat_item_to_char = normalize(flat_item_to_char);
    this_mo.SetRotationFromFacing(flat_item_to_char);
    // Calculate the direction the item is moving on the XZ plane
    vec3 flat_lin_dir = lin_vel;
    flat_lin_dir.y = 0.0f;
    flat_lin_dir = normalize(flat_lin_dir);
    // Determine which catch animation to use
    bool mirror = mirrored_stance;
    string anim_path;
    if(dot(flat_item_to_char, flat_lin_dir) < -0.95f){
        anim_path = "Data/Animations/r_blockfronthard.anm";
    } else {
        anim_path = "Data/Animations/r_hitspinright.anm";
        vec3 perp = vec3(flat_item_to_char.z, 0.0f, -flat_item_to_char.x);
        mirror = (dot(perp, flat_lin_dir) < 0.0f);
    }
    // Start catch animation
    SetState(_hit_reaction_state);
    hit_reaction_anim_set = true;
    int8 flags = _ANM_MOBILE | _ANM_FROM_START;
    if(mirror){
        flags = flags | _ANM_MIRRORED;
    }
    this_mo.SetAnimation(anim_path,10.0f,flags);
    this_mo.rigged_object().anim_client().SetAnimationCallback("void EndHitReaction()");

    PlayItemGrabSound(io, 1.0f);
    AttachWeapon(id);
}

void HitByItem(string material, vec3 point, int id, int type) {
    // Get force of object movement
    ItemObject@ io = ReadItemID(id);
    vec3 lin_vel = io.GetLinearVelocity();
    vec3 force = (lin_vel - this_mo.velocity) * io.GetMass();
    // Apply force to character velocity
    this_mo.velocity += force * 0.1f;
    // Take damage from item impact
    float force_len = length(force);
    TakeDamage(force_len / 30.0f);
    if(type == 1){
        TakeBloodDamage(force_len / 50.0f);
    }
    if(type == 2){
        TakeBloodDamage(force_len / 8.0f);
    }
    level.SendMessage("item_hit "+this_mo.getID());
    bool knocked_over = (length(force) > 20.0f || knocked_out != _awake || !on_ground);
    if(knocked_over){
        HandleRagdollImpactImpulse(force * 200.0f, point, 0.0f);
    } else {
        // Set character rotation to opposite of item velocity
        vec3 face_dir = lin_vel * -1.0f;
        face_dir.y = 0.0f;
        face_dir = normalize(face_dir);
        this_mo.SetRotationFromFacing(face_dir);
        // Apply hit reaction animation
        reaction_getter.Load("Data/Attacks/reaction_medfront.xml");
        string anim_path = reaction_getter.GetAnimPath(force_len/20.0f);
        SetState(_hit_reaction_state);
        hit_reaction_anim_set = true;
        int8 flags = _ANM_MOBILE | _ANM_FROM_START;
        if(mirrored_stance){
            flags = flags | _ANM_MIRRORED;
        }
        this_mo.SetAnimation(anim_path,10.0f,flags);
        this_mo.rigged_object().anim_client().SetAnimationCallback("void EndHitReaction()");
    }
}

vec3 GetVelocityForTarget(const vec3&in start, const vec3&in end, float max_horz, float max_vert, float arc, float&out time){
    vec3 rel_vec = end - start;
    vec3 rel_vec_flat = vec3(rel_vec.x, 0.0f, rel_vec.z);
    vec3 flat = vec3(xz_distance(start, end), rel_vec.y, 0.0f);
    float min_x_time = flat.x / max_horz;
    float grav = physics.gravity_vector.y;
    if(2*grav*flat.y+max_vert*max_vert <= 0.0f){
        return vec3(0.0f);
    }
    float max_y_time = (sqrt(2*grav*flat.y+max_vert*max_vert) + max_vert)/-grav;
    if(min_x_time > max_y_time){
        return vec3(0.0f);
    }
    time = mix(min_x_time, max_y_time, arc);
    vec3 flat_vel(flat.x / time,
                  flat.y / time - physics.gravity_vector.y * time * 0.5f,
                  0.0f);
    //Print("Flat vel: "+flat_vel.x+" "+flat_vel.y+"\n");
    vec3 vel = flat_vel.x * normalize(rel_vec_flat) + vec3(0.0f, flat_vel.y, 0.0f);
    //Print("Vel: "+vel.x+" "+vel.y+" "+vel.z+"\n");
    return vel;
}
    
void Collided(float impulse){
    if(impulse < 5.0f){
        return;
    }
    const float _impact_damage_mult = 0.005f;
    int old_knocked_out = knocked_out;
    float damage = impulse*_impact_damage_mult;
    PossibleHeadBleed(damage);
    TakeDamage(damage);
    if(old_knocked_out == _awake && knocked_out == _unconscious){
        string sound = "Data/Sounds/hit/hit_medium_juicy.xml";
        PlaySoundGroup(sound, this_mo.position);
    }
    if(old_knocked_out != _dead && knocked_out == _dead){
        string sound = "Data/Sounds/hit/hit_hard.xml";
        PlaySoundGroup(sound, this_mo.position);
        SetRagdollType(_RGDL_LIMP);
    }
}

int IsBlockStunned() {
    return (block_stunned > 0.0f)?1:0;
}

vec3 FlipFacing() {
    if(target_id != -1 && throw_knife_layer_id != -1){
        MovementObject@ mo = ReadCharacterID(target_id);
        vec3 vec = mo.position - this_mo.position;
        vec.y = 0.0f;
        vec = normalize(vec);
        return vec;
    } else {
        return camera.GetFlatFacing();
    }
}

void MouseControlJumpTest() {
    vec3 start = camera.GetPos();
    vec3 end = camera.GetPos() + camera.GetMouseRay()*400.0f;
    col.GetSweptSphereCollision(start, end, _leg_sphere_size);
    DebugDrawWireSphere(sphere_col.position, _leg_sphere_size, vec3(0.0f,1.0f,0.0f), _delete_on_update);
    vec3 rel_dist = sphere_col.position - this_mo.position;
    vec3 flat_rd = vec3(rel_dist.x, 0.0f, rel_dist.z);
    vec3 jump_target = sphere_col.position;
    this_mo.SetRotationFromFacing(flat_rd);
    float time;
    vec3 start_vel = GetVelocityForTarget(this_mo.position, sphere_col.position, run_speed*1.5f, _jump_vel*1.7f, 0.55f, time);
    if(start_vel.y != 0.0f){
        bool low_success = false;
        bool med_success = false;
        bool high_success = false;
        const float _success_threshold = 0.1f;
        vec3 new_end;
        vec3 low_vel = GetVelocityForTarget(this_mo.position, jump_target, run_speed*1.5f, _jump_vel*1.7f, 0.15f, time);
        jump_info.jump_start_vel = low_vel;
        JumpTestEq(this_mo.position, jump_info.jump_start_vel, jump_info.jump_path); 
        new_end = jump_info.jump_path[jump_info.jump_path.size()-1];
        for(int i=0; i<int(jump_info.jump_path.size())-1; ++i){
            DebugDrawLine(jump_info.jump_path[i] - vec3(0.0f, _leg_sphere_size, 0.0f), 
                jump_info.jump_path[i+1] - vec3(0.0f, _leg_sphere_size, 0.0f), 
                vec3(1.0f,0.0f,0.0f), 
                _delete_on_update);
        }
        if(jump_info.jump_path.size() != 0){
            vec3 land_point = jump_info.jump_path[jump_info.jump_path.size()-1];
            DebugDrawWireSphere(land_point, _leg_sphere_size, vec3(1.0f,0.0f,0.0f), _delete_on_update);
            if(distance_squared(land_point, jump_target) < _success_threshold){
                low_success = true;
            }
        } 
        vec3 med_vel = GetVelocityForTarget(this_mo.position, jump_target, run_speed*1.5f, _jump_vel*1.7f, 0.55f, time);
        jump_info.jump_start_vel = med_vel;
        JumpTestEq(this_mo.position, jump_info.jump_start_vel, jump_info.jump_path); 
        new_end = jump_info.jump_path[jump_info.jump_path.size()-1];
        for(int i=0; i<int(jump_info.jump_path.size())-1; ++i){
            DebugDrawLine(jump_info.jump_path[i] - vec3(0.0f, _leg_sphere_size, 0.0f), 
                jump_info.jump_path[i+1] - vec3(0.0f, _leg_sphere_size, 0.0f), 
                vec3(0.0f,0.0f,1.0f), 
                _delete_on_update);
        }
        if(jump_info.jump_path.size() != 0){
            vec3 land_point = jump_info.jump_path[jump_info.jump_path.size()-1];
            DebugDrawWireSphere(land_point, _leg_sphere_size, vec3(1.0f,0.0f,0.0f), _delete_on_update);
            if(distance_squared(land_point, jump_target) < _success_threshold){
                med_success = true;
            }
        } 
        vec3 high_vel = GetVelocityForTarget(this_mo.position, jump_target, run_speed*1.5f, _jump_vel*1.7f, 1.0f, time);
        jump_info.jump_start_vel = high_vel;
        JumpTestEq(this_mo.position, jump_info.jump_start_vel, jump_info.jump_path); 
        new_end = jump_info.jump_path[jump_info.jump_path.size()-1];
        for(int i=0; i<int(jump_info.jump_path.size())-1; ++i){
            DebugDrawLine(jump_info.jump_path[i] - vec3(0.0f, _leg_sphere_size, 0.0f), 
                jump_info.jump_path[i+1] - vec3(0.0f, _leg_sphere_size, 0.0f), 
                vec3(0.0f,1.0f,0.0f), 
                _delete_on_update);
        }
        if(jump_info.jump_path.size() != 0){
            vec3 land_point = jump_info.jump_path[jump_info.jump_path.size()-1];
            DebugDrawWireSphere(land_point, _leg_sphere_size, vec3(0.0f,1.0f,0.0f), _delete_on_update);
            if(distance_squared(land_point, jump_target) < _success_threshold){
                high_success = true;
            }
        }
        jump_info.jump_path.resize(0);

        if(low_success){
            start_vel = low_vel;
        } else if(med_success){
            start_vel = med_vel;
        } else if(high_success){
            start_vel = high_vel;
        } else {
            start_vel = vec3(0.0f);
        }

        if(GetInputPressed(this_mo.controller_id, "mouse0") && start_vel.y != 0.0f){
            jump_info.StartJump(start_vel, true);
            SetOnGround(false);
        }
    }
}

void UpdateCutThroatEffect(const Timestep &in ts) {
    if(GetBloodLevel() == 0){
        return;
    }
    const float _blood_loss_speed = 0.5f;
    if(blood_delay <= 0){
        if(rand()%16 == 0){
            this_mo.rigged_object().CreateBloodDrip("head", 1, vec3(RangedRandomFloat(-1.0f,1.0f),RangedRandomFloat(-0.3f,0.3f),1.0f));//head_transform * vec3(0.0f,1.0f,0.0f));
        }
        vec3 head_pos = this_mo.rigged_object().GetAvgIKChainPos("head");
        vec3 torso_pos = this_mo.rigged_object().GetAvgIKChainPos("torso");
        vec3 bleed_pos = mix(head_pos, torso_pos, 0.2f);
        mat4 head_transform = this_mo.rigged_object().GetAvgIKChainTransform("head");
        head_transform.SetColumn(3, vec3(0.0f));
        float blood_force = sin(time*_spurt_frequency)*0.5f+0.5f;
        uint32 id = MakeParticle("Data/Particles/blooddrop.xml",bleed_pos,(head_transform*vec3(0.0f,blood_amount*blood_force,0.0f)+this_mo.velocity),GetBloodTint());
        //TintParticle(id, GetBloodTint());
        if(last_blood_particle_id != 0){
            ConnectParticles(last_blood_particle_id, id);
        }
        last_blood_particle_id = id;
        blood_delay = 2;
    }
    blood_amount -= ts.step() * _blood_loss_speed;
    spurt_sound_delay -= ts.step();
    if(spurt_sound_delay <= 0.0f){
        spurt_sound_delay += _spurt_delay_amount;
        vec3 head_pos = this_mo.rigged_object().GetAvgIKChainPos("head");
        vec3 torso_pos = this_mo.rigged_object().GetAvgIKChainPos("torso");
        vec3 bleed_pos = mix(head_pos, torso_pos, 0.2f);
        PlaySoundGroup("Data/Sounds/blood/artery_squirt.xml", bleed_pos, blood_amount/_max_blood_amount);
    }
    -- blood_delay;
}

void StartBodyDrag(string part, int part_id, int char_id){
    MovementObject@ char = ReadCharacterID(char_id);
    drag_body_part = part;
    drag_body_part_id = part_id;
    SetTetherID(char_id);
    SetTethered(_TETHERED_DRAGBODY);
    drag_strength_mult = 0.0f;
    char.Execute("SetTetherID(" + this_mo.getID() + ");" +
                 "SetTethered(_TETHERED_DRAGGEDBODY);");
}

void CheckForStartBodyDrag(){
    if(tethered == _TETHERED_FREE && this_mo.controlled && WantsToDragBody()){
        int closest_id = GetClosestCharacterID(2.0f, _TC_RAGDOLL | _TC_UNCONSCIOUS);
        if(closest_id != -1){
            vec3 drag_offset_world;
            drag_offset_world.x = this_mo.position.x;
            drag_offset_world.z = this_mo.position.z;
            MovementObject@ char = ReadCharacterID(closest_id);
            string closest_part = "";
            string test_part;
            int closest_part_id;
            int test_part_id;
            float closest_dist = 0.0f;
            for(int i=0; i<5; ++i){
                switch(i){
                    case 0: test_part = "head"; test_part_id = 0; break;
                    case 1: test_part = "leftarm"; test_part_id = 0;  break;
                    case 2: test_part = "rightarm"; test_part_id = 0;  break;
                    case 3: test_part = "left_leg"; test_part_id = 0;  break;
                    case 4: test_part = "right_leg"; test_part_id = 0; break;
                }
                float dist;
                dist = distance_squared(char.rigged_object().GetIKChainPos(test_part,test_part_id),
                                              this_mo.position);
                if(closest_part == "" || dist < closest_dist){
                    closest_dist = dist;
                    closest_part_id = test_part_id;
                    closest_part = test_part;
                }
            }
            if(head_choke_queue == closest_id){
                closest_part = "head";
                closest_part_id = 0;
                closest_dist = 0.0f;
                head_choke_queue = -1;
            }
            if(closest_dist <= _body_part_drag_dist * 1.5f){
                if(active_block_flinch_layer != -1){
                    this_mo.rigged_object().anim_client().RemoveLayer(active_block_flinch_layer, 4.0f);
                    active_block_flinch_layer = -1;
                } 

                StartBodyDrag(closest_part, closest_part_id, closest_id);
            }
        }
    }
}

void ApplyLevelBoundaries(){
    const float _level_size = 460.0f;
    const float _push_level_size = 450.0f;
    const float _push_force_mult = 0.2f;
    this_mo.position.x = max(-_level_size, min(_level_size, this_mo.position.x));
    this_mo.position.z = max(-_level_size, min(_level_size, this_mo.position.z));
    vec3 push_force;
    if(this_mo.position.x < -_push_level_size){
        push_force.x -= (this_mo.position.x + _push_level_size);
    }
    if(this_mo.position.x > _push_level_size){
        push_force.x -= (this_mo.position.x - _push_level_size);
    }
    if(this_mo.position.z < -_push_level_size){
        push_force.z -= (this_mo.position.z + _push_level_size);
    }
    if(this_mo.position.z > _push_level_size){
        push_force.z -= (this_mo.position.z - _push_level_size);
    }
    push_force *= _push_force_mult;
    if(length_squared(push_force) > 0.0f){
        this_mo.velocity += push_force;
        if(state == _ragdoll_state){
            this_mo.rigged_object().ApplyForceToRagdoll(push_force * 500.0f, this_mo.rigged_object().skeleton().GetCenterOfMass());       
        }
    }
}

void MakeBeaconParticle(){
    if(!this_mo.controlled && knocked_out == _awake && distance_squared(camera.GetPos(), this_mo.position) > 100.0f){
        MakeParticle("Data/Particles/rayspark.xml",this_mo.position,vec3(0.0f,500.0f,0.0f));
    }
}

void SetTargetID(int id){
    target_id = id;
}

void MovementObjectDeleted(int id){
    if(id == target_id){
        SetTargetID(-1);      
    }
    if(id == attacked_by_id){
        attacked_by_id = -1;       
    }
    if(id == force_look_target_id){
        force_look_target_id = -1;       
    }
    if(id == look_target.id){
        look_target.id = -1;
        look_target.type = _none;
    }
    AIMovementObjectDeleted(id);
}

void PrintWeaponSlotDebugText(){  
    DebugText("char"+this_mo.getID()+"0","Character ID: "+this_mo.getID(), 0.5f);
    DebugText("char"+this_mo.getID()+"00","Pos: "+
        FloatString(this_mo.position.x,6)+", "+
        FloatString(this_mo.position.y,6)+", "+
        FloatString(this_mo.position.z,6), 0.5f);
    DebugText("char"+this_mo.getID()+"1","Weapon slot \"held left\"     : "+weapon_slots[_held_left], 0.5f);
    DebugText("char"+this_mo.getID()+"2","Weapon slot \"held right\"    : "+weapon_slots[_held_right], 0.5f);
    DebugText("char"+this_mo.getID()+"3","Weapon slot \"sheathed left\" : "+weapon_slots[_sheathed_left], 0.5f);
    DebugText("char"+this_mo.getID()+"4","Weapon slot \"sheathed right\": "+weapon_slots[_sheathed_right], 0.5f);
    DebugText("char"+this_mo.getID()+"5","Weapon slot \"sheath left\"   : "+weapon_slots[_sheathed_left_sheathe], 0.5f);
    DebugText("char"+this_mo.getID()+"6","Weapon slot \"sheath right\"  : "+weapon_slots[_sheathed_right_sheathe], 0.5f);
    DebugText("char"+this_mo.getID()+"7","Primary weapon slot: "+primary_weapon_slot, 0.5f);
}

string StateStr(int val){
    switch(val){
        case _movement_state:     return "_movement_state";
        case _ground_state:       return "_ground_state";
        case _attack_state:       return "_attack_state";
        case _hit_reaction_state: return "_hit_reaction_state";
        case _ragdoll_state:      return "_ragdoll_state";
    }
    return "unknown";
}

string TetheredStr(int val){
    switch(val){
        case _TETHERED_FREE:        return "_TETHERED_FREE";
        case _TETHERED_REARCHOKE:   return "_TETHERED_REARCHOKE";
        case _TETHERED_REARCHOKED:  return "_TETHERED_REARCHOKED";
        case _TETHERED_DRAGBODY:    return "_TETHERED_DRAGBODY";
        case _TETHERED_DRAGGEDBODY: return "_TETHERED_DRAGGEDBODY";
    }
    return "unknown";
}

void SetIKChainElementInflate(const string &in name, int el, float val) {
    if(!this_mo.rigged_object().skeleton().IKBoneExists(name)){
        return;
    }
    int bone = this_mo.rigged_object().skeleton().IKBoneStart(name);
    for(int i=0; i<el; ++i){
        bone = this_mo.rigged_object().skeleton().GetParent(bone);
        if(bone == -1){
            return;
        }
    }
    this_mo.rigged_object().skeleton().SetBoneInflate(bone, val);
}

void SetIKChainInflate(const string &in name, float val) {
    if(!this_mo.rigged_object().skeleton().IKBoneExists(name)){
        return;
    }
    int bone = this_mo.rigged_object().skeleton().IKBoneStart(name);
    int chain_len = this_mo.rigged_object().skeleton().IKBoneLength(name);
    for(int i=0; i<chain_len; ++i){
        this_mo.rigged_object().skeleton().SetBoneInflate(bone, val);
        bone = this_mo.rigged_object().skeleton().GetParent(bone);
        if(bone == -1){
            break;
        }
    }
}

void ApplyBoneInflation() {
    int num_bones = this_mo.rigged_object().skeleton().NumBones();
    for(int i=0; i<num_bones; ++i){
        this_mo.rigged_object().skeleton().SetBoneInflate(i, 1.0f);
    }

    const float fat = p_fat;
    const float muscle = p_muscle;
    const float ear_size = p_ear_size;
    
    SetIKChainElementInflate("torso",2,max(0.7f+muscle*0.5f, 1.0f + max(fat*0.5f,fat)));
    SetIKChainElementInflate("torso",1,max(0.5f+muscle*0.2f, 1.0f + max(fat*0.75f,fat)));
    SetIKChainElementInflate("torso",0,1.0f + max(max(0.0f,fat), muscle*0.3f));

    SetIKChainElementInflate("head",1,1.0f + fat);

    SetIKChainInflate("leftear", ear_size);
    SetIKChainInflate("rightear", ear_size);

    SetIKChainElementInflate("left_leg",5,1.0f + max(fat, muscle*0.4f));
    SetIKChainElementInflate("left_leg",4,max(muscle, 1.0f + fat * 0.5f));
    SetIKChainElementInflate("left_leg",3,1.0f + max(fat * 0.25f, muscle*0.6f));
    SetIKChainElementInflate("left_leg",2,1.0f + max(fat * 0.5f, muscle*0.3f));

    SetIKChainElementInflate("right_leg",5,1.0f + max(fat, muscle*0.4f));
    SetIKChainElementInflate("right_leg",4,max(muscle, 1.0f + fat * 0.5f));
    SetIKChainElementInflate("right_leg",3,1.0f + max(fat * 0.25f, muscle*0.6f));
    SetIKChainElementInflate("right_leg",2,1.0f + max(fat * 0.5f, muscle*0.3f));

    SetIKChainElementInflate("leftarm",1,max(0.6f, 1.0f + max(fat*0.5f,muscle*0.5f)));
    SetIKChainElementInflate("leftarm",2,max(0.6f, 1.0f + max(fat*0.5f,muscle*0.7f)));
    SetIKChainElementInflate("leftarm",3,max(0.6f, 1.0f + max(fat, muscle)));
    SetIKChainElementInflate("leftarm",4,max(0.6f, 1.0f + max(fat, muscle)));
    SetIKChainElementInflate("leftarm",5,max(0.6f, 1.0f + max(fat*0.5f,muscle)));
    
    SetIKChainElementInflate("rightarm",1,max(0.6f, 1.0f + max(fat*0.5f,muscle*0.5f)));
    SetIKChainElementInflate("rightarm",2,max(0.6f, 1.0f + max(fat*0.5f,muscle*0.7f)));
    SetIKChainElementInflate("rightarm",3,max(0.6f, 1.0f + max(fat, muscle)));
    SetIKChainElementInflate("rightarm",4,max(0.6f, 1.0f + max(fat, muscle)));
    SetIKChainElementInflate("rightarm",5,max(0.6f, 1.0f + max(fat*0.5f,muscle)));
}

array<BoneTransform> skeleton_bind_transforms;
array<BoneTransform> inv_skeleton_bind_transforms;
array<int> ik_chain_elements;
enum IKLabel {kLeftArmIK, kRightArmIK, kLeftLegIK, kRightLegIK, 
              kHeadIK, kLeftEarIK, kRightEarIK, kTorsoIK, 
              kTailIK, kNumIK };
array<int> ik_chain_start_index;
array<int> ik_chain_length;
array<float> ik_chain_bone_lengths;
array<int> bone_children;
array<int> bone_children_index;
array<vec3> convex_hull_points;
array<int> convex_hull_points_index;

void CacheSkeletonInfo() {
    Print("Caching skeleton info\n");
    RiggedObject@ rigged_object = this_mo.rigged_object();
    Skeleton@ skeleton = rigged_object.skeleton();
    int num_bones = skeleton.NumBones();
    skeleton_bind_transforms.resize(num_bones);
    inv_skeleton_bind_transforms.resize(num_bones);
    for(int i=0; i<num_bones; ++i){
        skeleton_bind_transforms[i] = BoneTransform(skeleton.GetBindMatrix(i));
        inv_skeleton_bind_transforms[i] = invert(skeleton_bind_transforms[i]);
    }

    ik_chain_elements.resize(0);
    ik_chain_bone_lengths.resize(0);
    ik_chain_start_index.resize(kNumIK);
    ik_chain_length.resize(kNumIK);
    for(int i=0; i<kNumIK; ++i) {
        string bone_label;
        switch(i){
            case kLeftArmIK: bone_label = "leftarm"; break;
            case kRightArmIK: bone_label = "rightarm"; break;
            case kLeftLegIK: bone_label = "left_leg"; break;
            case kRightLegIK: bone_label = "right_leg"; break;
            case kHeadIK: bone_label = "head"; break;
            case kLeftEarIK: bone_label = "leftear"; break;
            case kRightEarIK: bone_label = "rightear"; break;
            case kTorsoIK: bone_label = "torso"; break;
            case kTailIK: bone_label = "tail"; break;
        }
        int bone = skeleton.IKBoneStart(bone_label);
        ik_chain_length[i] = skeleton.IKBoneLength(bone_label);
        ik_chain_start_index[i] = ik_chain_elements.size();
        int count = 0;
        while(bone != -1 && count < ik_chain_length[i]){
            ik_chain_bone_lengths.push_back(distance(skeleton.GetPointPos(skeleton.GetBonePoint(bone, 0)), skeleton.GetPointPos(skeleton.GetBonePoint(bone, 1))));
            ik_chain_elements.push_back(bone);
            bone = skeleton.GetParent(bone);
            ++count;
        }
    }
    ik_chain_start_index.push_back(ik_chain_elements.size());
    bone_children.resize(0);
    bone_children_index.resize(num_bones);
    for(int bone=0; bone<num_bones; ++bone){
        bone_children_index[bone] = bone_children.size();
        for(int i=0; i<num_bones; ++i){
            int temp_bone = i;
            while(skeleton.GetParent(temp_bone) != -1 && skeleton.GetParent(temp_bone) != bone){
                temp_bone = skeleton.GetParent(temp_bone);
            }
            if(skeleton.GetParent(temp_bone) == bone){
                bone_children.push_back(i);
            }
        }
    }
    bone_children_index.push_back(bone_children.size());

    convex_hull_points.resize(0);
    convex_hull_points_index.resize(num_bones);
    for(int bone=0; bone<num_bones; ++bone){
        convex_hull_points_index[bone] = convex_hull_points.size();
        array<float> @hull_points = skeleton.GetConvexHullPoints(bone);
        for(int i=0, len=hull_points.size(); i<len; i+=3){
            convex_hull_points.push_back(vec3(hull_points[i], hull_points[i+1], hull_points[i+2]));
        }
    }
    convex_hull_points_index.push_back(convex_hull_points.size());

    key_masses.resize(kNumKeys);
    root_bone.resize(kNumKeys);
    for(int j=0; j<2; ++j){
        int bone = skeleton.IKBoneStart(j==0?"left_leg":"right_leg");
        for(int i=0, len=skeleton.IKBoneLength(j==0?"left_leg":"right_leg"); i<len; ++i){
            key_masses[kLeftLegKey+j] += skeleton.GetBoneMass(bone);
            if(i<len-1){
                bone = skeleton.GetParent(bone);
            }
        }
        root_bone[kLeftLegKey+j] = bone;
    }
    for(int j=0; j<2; ++j){
        int bone = skeleton.IKBoneStart(j==0?"leftarm":"rightarm");
        for(int i=0, len=skeleton.IKBoneLength(j==0?"leftarm":"rightarm"); i<len; ++i){
            key_masses[kLeftArmKey+j] += skeleton.GetBoneMass(bone);
            if(i<len-1){
                bone = skeleton.GetParent(bone);
            }
        }
        root_bone[kLeftArmKey+j] = bone;
    }
    {
        int bone = skeleton.IKBoneStart("torso");
        for(int i=0, len=skeleton.IKBoneLength("torso"); i<len; ++i){
            key_masses[kChestKey] += skeleton.GetBoneMass(bone);
            if(i<len-1){
                bone = skeleton.GetParent(bone);
            }
        }
        root_bone[kChestKey] = bone;
    }
    {
        int bone = skeleton.IKBoneStart("head");
        for(int i=0, len=skeleton.IKBoneLength("head"); i<len; ++i){
            key_masses[kHeadKey] += skeleton.GetBoneMass(bone);
            if(i<len-1){
                bone = skeleton.GetParent(bone);
            }
        }
        root_bone[kHeadKey] = bone;
    }
}

float vision_check_time = 0.0f;
void UpdateVision() {
    // Get list of objects in character view frustum
    BoneTransform transform = this_mo.rigged_object().GetFrameMatrix(ik_chain_elements[ik_chain_start_index[kHeadIK]]);
    if(transform != transform){
        DisplayError("Error", "NaN in UpdateVision()");
    }
    transform.rotation = transform.rotation * quaternion(vec4(1,0,0,-70/180.0f*3.1417f));
    array<int> visible_objects;
    GetObjectsInHull("Data/Models/fov.obj", transform.GetMat4(), visible_objects);
    for(int i=0, len=visible_objects.size(); i<len; ++i){
        int id = visible_objects[i];
        if(ReadObjectFromID(id).GetType() == _item_object){
            // Get a random point on the item for line-of-sight check
            ItemObject@ item = ReadItemID(id);
            vec3 check_point = item.GetPhysicsPosition(); // Default to item COM in case lines are undefined
            int num_lines = item.GetNumLines();
            if(num_lines != 0){
                // Get total length of all item lines
                float total_line_length = 0.0f;
                for(int j=0; j<num_lines; ++j){
                    total_line_length += distance(item.GetLineStart(j), item.GetLineEnd(j));
                }
                // Pick a random point on the lines
                float rand_val = RangedRandomFloat(0.0f, total_line_length);
                total_line_length = 0.0f;
                for(int j=0; j<num_lines; ++j){
                    float line_length = distance(item.GetLineStart(j), item.GetLineEnd(j));
                    if(rand_val < total_line_length + line_length){
                        float t;
                        if(line_length != 0.0f){
                            t = (rand_val - total_line_length) / line_length;
                        } else {
                            t = 0.0f;
                        }
                        check_point = item.GetPhysicsTransform() * mix(item.GetLineStart(j), item.GetLineEnd(j), t);
                    }
                    total_line_length += line_length;
                }
            }
            vec3 hit = col.GetRayCollision(transform.origin, check_point);
            bool draw_vision_lines = false;
            if(draw_vision_lines){
                if(hit == check_point){
                    DebugDrawLine(transform.origin, check_point, vec3(0.0f,1.0f,0.0f), _fade);
                } else {
                    DebugDrawLine(transform.origin, hit, vec3(1.0f,0.0f,0.0f), _fade);                
                }
            }
            if(hit == check_point){
                situation.Notice(id);
            }
        }
    }
}

void CheckForNANPosAndVel(int num){
    if(this_mo.position != this_mo.position){
        Print("Invalid position at "+num+"\n");
        Breakpoint(0);
    }
    if(this_mo.velocity != this_mo.velocity){
        Print("Invalid velocity at "+num+"\n");
        Breakpoint(0);
    }
}

void CheckForNANVec3(const vec3 &in vec, int num){
    if(vec != vec){
        Print("Invalid vec3 at "+num+"\n");
        Breakpoint(0);
    }
}

void DisplayMatrixUpdate(){
    //if(!animated){
    //    Print("Testing ragdoll!\n");
    //}
    RiggedObject@ rigged_object = this_mo.rigged_object();
    float scale = rigged_object.GetCharScale();
    int chest_bone = ik_chain_elements[ik_chain_start_index[kTorsoIK]];
    BoneTransform world_chest = BoneTransform(rigged_object.GetDisplayBoneMatrix(chest_bone)) * inv_skeleton_bind_transforms[chest_bone];
    vec3 breathe_dir = world_chest.rotation * normalize(vec3(0,0,1));
    vec3 breathe_front = world_chest.rotation * normalize(vec3(0,1,0));
    vec3 breathe_side = world_chest.rotation * normalize(vec3(1,0,0));
    for(int i=0; i<2; ++i){
        int collar_bone = ik_chain_elements[ik_chain_start_index[kLeftArmIK+i]+5];
        BoneTransform collar = BoneTransform(rigged_object.GetDisplayBoneMatrix(collar_bone)) * inv_skeleton_bind_transforms[collar_bone];
        collar.origin += breathe_dir * breath_amount * 0.01f * scale;
        collar.origin += breathe_front * breath_amount * 0.01f * scale;
        collar = collar * skeleton_bind_transforms[collar_bone];
        rigged_object.SetDisplayBoneMatrix(collar_bone, collar.GetMat4());

        int shoulder_bone = ik_chain_elements[ik_chain_start_index[kLeftArmIK+i]+4];
        BoneTransform shoulder = BoneTransform(rigged_object.GetDisplayBoneMatrix(shoulder_bone)) * inv_skeleton_bind_transforms[shoulder_bone];
        shoulder.origin += breathe_dir * breath_amount * 0.002f * scale;
        shoulder = shoulder * skeleton_bind_transforms[shoulder_bone];
        rigged_object.SetDisplayBoneMatrix(shoulder_bone, shoulder.GetMat4());
    }

    //collarbone += breathe_dir * breath_amount * 0.01f * scale;
    //ribs += breathe_dir * breath_amount *  0.01f * scale;
    //ribs += world_chest.rotation * normalize(vec3(0,1,0.5)) * breath_amount * 0.01f * scale;
    //stomach += breathe_dir * breath_amount *  0.01f * scale;

    world_chest.origin += breathe_dir * breath_amount * 0.01f * scale;
    world_chest.origin += breathe_front * breath_amount * 0.01f * scale;
    world_chest.rotation = quaternion(vec4(breathe_side.x, breathe_side.y, breathe_side.z, breath_amount * 0.05f)) * world_chest.rotation;
    world_chest = world_chest * skeleton_bind_transforms[chest_bone];
    rigged_object.SetDisplayBoneMatrix(chest_bone, world_chest.GetMat4());

    int abdomen_bone = ik_chain_elements[ik_chain_start_index[kTorsoIK]+1];
    BoneTransform abdomen = BoneTransform(rigged_object.GetDisplayBoneMatrix(abdomen_bone)) * inv_skeleton_bind_transforms[abdomen_bone];
    abdomen.origin += breathe_dir * breath_amount * 0.008f * scale;
    abdomen.origin += breathe_front * breath_amount * 0.005f * scale;
    abdomen.rotation = quaternion(vec4(breathe_side.x, breathe_side.y, breathe_side.z, breath_amount * -0.02f)) * abdomen.rotation;
    abdomen = abdomen * skeleton_bind_transforms[abdomen_bone];
    rigged_object.SetDisplayBoneMatrix(abdomen_bone, abdomen.GetMat4());


    int neck_bone = ik_chain_elements[ik_chain_start_index[kHeadIK]+1];
    BoneTransform neck = BoneTransform(rigged_object.GetDisplayBoneMatrix(neck_bone)) * inv_skeleton_bind_transforms[neck_bone];
    neck.origin += breathe_dir * breath_amount * 0.005f * scale;
    neck = neck * skeleton_bind_transforms[neck_bone];
    rigged_object.SetDisplayBoneMatrix(neck_bone, neck.GetMat4());
        
}

/*
array<vec3> cloth_points;
array<vec3> old_cloth_points;
array<vec3> temp_cloth_points;

void UpdateCloth(const Timestep &in ts) {
    if(cloth_points.size() == 0){
        cloth_points.resize(100);
        int index = 0;
        for(int i=0; i<10; ++i){
            for(int j=0;j<10;++j){
                cloth_points[index] = 0.0f;
                ++index;
            }
        }
    }
    old_cloth_points.resize(100);
    temp_cloth_points.resize(100);

    // Apply velocity and store old cloth points
    for(int i=0; i<100; ++i){
        vec3 vel = cloth_points[i]-old_cloth_points[i];
        if(length_squared(vel)>1.0f){
            vel = normalize(vel);
        }
        temp_cloth_points[i] = cloth_points[i] + vel*0.99f;
        temp_cloth_points[i].y -= 0.001f;
        old_cloth_points[i] = cloth_points[i];
        cloth_points[i] = temp_cloth_points[i];
        temp_cloth_points[i] = 0.0f;
    }

    { // Enforce distance constraints
        int index=0;
        for(int i=0; i<100; ++i){
            temp_cloth_points[i] = 0.0f;
        }
        for(int i=0; i<10; ++i){
            for(int j=0;j<10;++j){
                if(j!=9){
                    float dist = distance(cloth_points[index], cloth_points[index+1]);
                    vec3 dir = normalize(cloth_points[index+1] - cloth_points[index]);
                    temp_cloth_points[index+1] += dir * (0.1f-dist)*0.5f;
                    temp_cloth_points[index] -= dir * (0.1f-dist)*0.5f;
                }
                if(i!=9){
                    float dist = distance(cloth_points[index], cloth_points[index+10]);
                    vec3 dir = normalize(cloth_points[index+10] - cloth_points[index]);
                    DebugText("dist","dist: "+dist, 0.5f);
                    temp_cloth_points[index+10] += dir * (0.1f-dist)*0.5f;
                    temp_cloth_points[index] -= dir * (0.1f-dist)*0.5f;
                }
                ++index;
            }
        }
        for(int i=0; i<100; ++i){
            temp_cloth_points[i] *= 0.5f;
        }
        for(int i=0; i<100; ++i){
            vec3 temp_point = cloth_points[i];
            temp_point -= this_mo.position;
            temp_point.x *= 4.0f;
            temp_point.z *= 4.0f;
            if(length_squared(temp_point) < 1.0f){
                vec3 temp_old_point = cloth_points[i];
                temp_old_point -= this_mo.position;
                temp_old_point.x *= 4.0f;
                temp_old_point.z *= 4.0f;

                for(int j=0; j<10; ++j){
                    vec3 new_temp_point = mix(temp_old_point, temp_point, j/9.0f);
                    if(length_squared(new_temp_point) < 1.0f){
                        temp_point = normalize(temp_point);
                        temp_point.x *= 0.25f;
                        temp_point.z *= 0.25f;
                        temp_point += this_mo.position;
                        break;
                    }
                }
                temp_cloth_points[i] += temp_point - cloth_points[i];
            }
        }
        for(int i=0; i<100; ++i){
            cloth_points[i] += temp_cloth_points[i];// * 0.5f;
        }
    }

    DebugText("Cloth point", "Cloth point: "+cloth_points[0], 1.0f);

    {
        vec3 facing = this_mo.GetFacing();
        vec3 right =  vec3(facing.z, 0, -facing.x);
        int index = 0;
        for(int i=0; i<10; ++i){
            for(int j=0;j<10;++j){
                if(j==9){
                    cloth_points[index] = this_mo.position + right*(0.1f*i-0.45f)+vec3(0,j*0.1f,0) - this_mo.GetFacing()*0.2f;
                }
                ++index;
            }
        }
        DebugDrawWireScaledSphere(this_mo.position,1.0f,vec3(0.25f,1.0f,0.25f), vec3(1.0f),_delete_on_update);
    }

    int index=0;
    for(int i=0; i<10; ++i){
        for(int j=0;j<10;++j){
            if(j!=9){
                DebugDrawLine(cloth_points[index], cloth_points[index+1],vec3(1.0f), _delete_on_update);
            }
            if(i!=9){
                DebugDrawLine(cloth_points[index], cloth_points[index+10],vec3(1.0f), _delete_on_update);
            }
            ++index;
        }
    }
}*/

float breath_amount = 0.0f;
float breath_time = 0.0f;
float breath_speed = 0.9f;
array<float> resting_mouth_pose;
array<float> target_resting_mouth_pose;
float resting_mouth_pose_time = 0.0f;

void Update(int num_frames) {
    CheckForNANPosAndVel(1);
    Timestep ts(time_step, num_frames);    
    time += ts.step();

    // Update talking
    if(test_talking){
        test_talking_amount = min(test_talking_amount + ts.step() * 20.0f, 1.0f);
        speak_sound_delay -= ts.step();
        if(speak_sound_delay <= 0.0f){
            string sound = "Data/Sounds/voice/speak_test/speak_test.xml";
            speak_sound_delay = 0.25f;
        }
    } else {
        test_talking_amount = max(test_talking_amount - ts.step() * 5.0f, 0.0f);
    }

    if(resting_mouth_pose.size() == 0){
        resting_mouth_pose.resize(4);
        target_resting_mouth_pose.resize(4);
        for(int i=0; i<4; ++i){
            resting_mouth_pose[i] = 0.0f;
            target_resting_mouth_pose[i] = 0.0f;
        }
    }
    if(knocked_out == _awake && resting_mouth_pose_time < time){
        resting_mouth_pose_time = time + RangedRandomFloat(0.2f,1.0f);
        for(int i=0; i<4; ++i){
            target_resting_mouth_pose[i] = max(0.0f, RangedRandomFloat(-8.0f,1.0f))*0.2f;
        }
    }
    for(int i=0; i<4; ++i){
        resting_mouth_pose[i] = mix(target_resting_mouth_pose[i], resting_mouth_pose[i], pow(0.97f, num_frames));
    }

    float talk_speed_mult = 1.5f;
    this_mo.rigged_object().SetMorphTargetWeight("ah",max(resting_mouth_pose[0], (sin(time*22.0f*talk_speed_mult)*0.5f+0.5f)*0.3f*test_talking_amount), 1.0f);
    this_mo.rigged_object().SetMorphTargetWeight("oh",max(resting_mouth_pose[1], ((sin(time*6.0f*talk_speed_mult)+sin(time*13.0f))*0.25f+0.5f)*0.7f*test_talking_amount), 1.0f);
    this_mo.rigged_object().SetMorphTargetWeight("w",max(resting_mouth_pose[2], (sin(time*15.0f*talk_speed_mult)*0.5f+0.5f)*0.3f*test_talking_amount), 1.0f);
    this_mo.rigged_object().SetMorphTargetWeight("mouth_open",max(resting_mouth_pose[3], max(injured_mouth_open, (sin(time*12.0f*talk_speed_mult)*0.5f+0.5f)*0.3f*test_talking_amount)), 1.0f);

    /*if(this_mo.controlled){
        DebugText("breath_speed","breath_speed: "+breath_speed, 0.5f);
    }*/

    if(knocked_out != _dead){
        float speed_ratio = length(this_mo.velocity)/max_speed;
        if(idle_type == _combat){
            speed_ratio = mix(speed_ratio,1.0f,0.5f);
        }
        float target_breath_speed = 0.9f+4.0f*speed_ratio;
        float breath_inertia = mix(0.999f, 0.99f, speed_ratio);
        breath_speed = min(5.0f, mix(target_breath_speed, breath_speed, pow(breath_inertia, num_frames)));
        breath_time += ts.step() * breath_speed;
        breath_amount = (sin(breath_time)*0.5f+0.5f)* 1.0f*mix(0.5f,1.0f,breath_speed/5.0f);
    }
    
    CheckForNANPosAndVel(2);
    // Cinematic posing
    if(dialogue_control){
        on_ground = true;
        if(this_mo.position != dialogue_position){
            this_mo.position = dialogue_position;
            ResetSecondaryAnimation();
        }
        tilt_modifier = vec3(0.0f,1.0f,0.0f);
        flip_modifier_rotation = 0.0f;
        this_mo.SetAnimation(dialogue_anim, 3.0f, 0);
        idle_stance_amount = 0.2f;

        torso_look = normalize(dialogue_torso_target-this_mo.rigged_object().GetAvgIKChainPos("torso"))*dialogue_torso_control;
        head_look = normalize(dialogue_head_target-this_mo.rigged_object().GetAvgIKChainPos("head"))*dialogue_head_control;
        eye_look_target = dialogue_eye_dir;

        UpdateBlink(ts);
        HandleFootStance(ts);
        {
            vec3 ik_pos = this_mo.rigged_object().GetAvgIKChainPos("torso");
            vec3 dir = normalize(dialogue_torso_target - ik_pos);
            float head_bob = 0.1f * test_talking_amount+0.02f;
            dir.y += (sin(time * 5.5) * 0.1f + sin(time * 9.5) * 0.1f)*head_bob;
            dir.x += (sin(time * 4.5) * 0.1f + sin(time * 7.5) * 0.1f)*head_bob;
            dir.z += (sin(time * 6.5) * 0.1f + sin(time * 8.5) * 0.1f)*head_bob;
            dir = normalize(dir);
            this_mo.rigged_object().SetIKTargetOffset("torso", dir*dialogue_torso_control);
        }
        {
            vec3 ik_pos = this_mo.rigged_object().GetAvgIKChainPos("head");
            float head_bob = 0.3f * test_talking_amount+0.02f;
            vec3 dir = normalize(dialogue_head_target - ik_pos);
            dir.y += (sin(time * 5) * 0.1f + sin(time * 12) * 0.1f)*head_bob;
            dir.x += (sin(time * 4) * 0.1f + sin(time * 10) * 0.1f)*head_bob;
            dir.z += (sin(time * 6) * 0.1f + sin(time * 11) * 0.1f)*head_bob;
            dir = normalize(dir);
            this_mo.rigged_object().SetIKTargetOffset("head",dir * dialogue_head_control);
        }
        if(this_mo.controlled){
            if(this_mo.controller_id == 0){
                UpdateAirWhooshSound();
            }
        }
        return;
    }
    CheckForNANPosAndVel(3);

    bool display_player_state = false;
    if(this_mo.controlled && display_player_state){
        DebugText("player_state","State: "+StateStr(state),0.5f);
        DebugText("tethered","Tethered: "+TetheredStr(tethered),0.5f);
        DebugText("animation","Animation: "+this_mo.rigged_object().anim_client().GetCurrAnim(),0.5f);
        DebugText("animation time","Animation time: "+this_mo.rigged_object().anim_client().GetNormalizedAnimTime(),0.5f);
    }
    
    if(target_id == -1 && force_look_target_id != -1){
        SetTargetID(force_look_target_id);
    }

    bool display_weapon_label = true;
    if(this_mo.controlled && display_weapon_label){
        if(weapon_slots[primary_weapon_slot] != -1){
            ItemObject@ item = ReadItemID(weapon_slots[primary_weapon_slot]);
            //DebugText("weapon_label","Weapon Label: "+item.GetLabel(),0.5f);
        }
    }
    CheckForNANPosAndVel(4);
    if(weapon_slots[primary_weapon_slot] == -1 && weapon_slots[secondary_weapon_slot] != -1){
        SwapWeaponHands();
    }
    
    if(vision_check_time <= time){
        UpdateVision();
        vision_check_time += RangedRandomFloat(0.3f,0.5f);
    }

    // Small swords never have a mirrored stance
    int primary_weapon_id = weapon_slots[primary_weapon_slot];
    if(primary_weapon_id != -1 && ReadItemID(primary_weapon_id).GetLabel() == "sword"){
        mirrored_stance = left_handed;
    }

    CheckForNANPosAndVel(5);
    // Set close coord so that long stances (like swords) don't penetrate other characters
    float close_amount = 0.0f;
    if(target_id != -1 && weapon_slots[primary_weapon_slot] != -1){
        MovementObject@ char = ReadCharacterID(target_id);
        if(char.GetIntVar("knocked_out") == _awake){
            float dist = distance(char.position, this_mo.position);
            float close_dist = 0.8f;
            float far_dist = 1.5f;
            float coord = 0.0f;
            if(dist < close_dist){
                coord = 1.0f;
            } else if(dist > far_dist){
                coord = 0.0f;
            } else {
                coord = 1.0f - (dist - close_dist) / (far_dist - close_dist);
            }
            close_amount = coord;
        }
    }
    this_mo.rigged_object().anim_client().SetBlendCoord("close_coord",close_amount);
  
    if(level.LevelBoundaries()){
        ApplyLevelBoundaries();
    }

    CheckForNANPosAndVel(6);
    // Simplified loop for testing out animations
    if(in_animation){        
        if(this_mo.controlled){
            if(this_mo.controller_id == 0){
                UpdateAirWhooshSound();
            }
            if(this_mo.controller_id == 0 || GetSplitscreen()){
                ApplyCameraControls(ts);
            }
        }
        ApplyPhysics(ts);
        HandleCollisions(ts);
        HandleSpecialKeyPresses();
        return;
    }    
    
    CheckForNANPosAndVel(7);
    if(being_executed == FINISHING_THROAT_CUT){
        int other_id = tether_id;
        CutThroat();
        vec3 impulse = this_mo.GetFacing() * 1000.0f;
        this_mo.rigged_object().ApplyForceToRagdoll(impulse, this_mo.rigged_object().GetIKChainPos("head", 1));
        ReadCharacterID(other_id).Execute("ChokedOut(" + this_mo.getID() + ");");
        being_executed = NO_EXECUTION;
    }

    if(cut_throat && blood_amount > 0.0f){
        UpdateCutThroatEffect(ts);
    }

    if(cut_torso && blood_amount > 0.0f){
        if(blood_delay <= 0){
            this_mo.rigged_object().CreateBloodDrip("torso", 1, vec3(0.0f,RangedRandomFloat(-1.0f,1.0f),RangedRandomFloat(-1.0f,1.0f)));
            blood_delay = 2;
        }
        blood_amount -= ts.step() * 0.5f;
        -- blood_delay;
    }
    CheckForNANPosAndVel(8);

    if(on_ground){
        push_velocity *= pow(0.9f, ts.frames());
        vec3 offset = this_mo.velocity - old_slide_vel;
        old_slide_vel = this_mo.velocity;
        this_mo.velocity = new_slide_vel + offset;
    } else {
        push_velocity = vec3(0.0f);
    }

    if(!this_mo.controlled && on_ground){
        //MouseControlJumpTest();
    }

    HandleSpecialKeyPresses();
    UpdateBrain(ts); //in playercontrol.as or enemycontrol.as
    UpdateState(ts);

    if(this_mo.controlled){
        if(this_mo.controller_id == 0){
            UpdateAirWhooshSound();
        }
        if(this_mo.controller_id == 0 || GetSplitscreen()){
            ApplyCameraControls(ts);
        }
    }

    if(on_ground){
        new_slide_vel = this_mo.velocity;
        float new_friction = GetFriction(this_mo.position + vec3(0.0f,_leg_sphere_size * -0.4f,0.0f));
        friction = max(0.01f, friction);
        friction = pow(mix(pow(friction,0.01f), pow(new_friction,0.01f), 0.05f),100.0f);
        this_mo.velocity = mix(this_mo.velocity, old_slide_vel, pow(1.0f-friction, ts.frames()));
        old_slide_vel = this_mo.velocity;
        for(int i=0; i<2; ++i){
            foot[i].old_pos += (old_slide_vel - new_slide_vel) * ts.step();
        }
    }
    CheckForNANPosAndVel(9);

	UpdateOGMP();
}

void JumpTest(const vec3&in initial_pos, 
              const vec3&in initial_vel,
              array<vec3>&inout jump_path,
              const Timestep &in ts) 
{
    const float _jump_test_steps = 40.0f;
    jump_path.resize(0);
    vec3 start = initial_pos;
    vec3 end = start;
    vec3 fake_vel = initial_vel;
    for(int i=0; i< 400; ++i){
        for(int j=0; j<_jump_test_steps / ts.frames(); ++j){
            fake_vel += physics.gravity_vector * ts.step();
            fake_vel = CheckTerminalVelocity(fake_vel, ts);
            end += fake_vel * ts.step();
        }
        jump_path.push_back(start);
        col.GetSweptSphereCollision(start,
                                     end,
                                     _leg_sphere_size);
        start = end;
        if(sphere_col.NumContacts() > 0){
            jump_path.push_back(sphere_col.position);
            break;
        }
    }
}

void JumpTestEq(const vec3&in initial_pos, 
                const vec3&in initial_vel,
                array<vec3>&inout jump_path) 
{
    const float _jump_test_steps = 20.0f;
    jump_path.resize(0);
    vec3 start = initial_pos;
    vec3 end = start;
    vec3 flat_vel = vec3(
        sqrt(initial_vel.x*initial_vel.x + initial_vel.z+initial_vel.z),
        initial_vel.y,
        0.0f);
    vec3 flat_dir = vec3(initial_vel.x, 0.0f, initial_vel.z);
    float time = 0.0f;
    float height;
    for(int i=0; i< 400; ++i){
        time += time_step * _jump_test_steps;
        height = flat_vel.y * time + 0.5f * physics.gravity_vector.y * time * time;
        end = initial_pos + flat_dir * time;
        end.y += height;
        jump_path.push_back(start);
        col.GetSweptSphereCollision(start,
                                     end,
                                     _leg_sphere_size);
        start = end;
        if(sphere_col.NumContacts() > 0){
            jump_path.push_back(sphere_col.position);
            break;
        }
    }
}

void EndAnim(){
    in_animation = false;
    this_mo.rigged_object().anim_client().SetAnimatedItemID(1, -1);
}

void RecoverHealth() {      
    SetKnockedOut(_awake);
    blood_health = 1.0f;
    block_health = 1.0f;
    blood_damage = 0.0f;
    temp_health = 1.0f;
    permanent_health = 1.0f;
}

void Recover() {      
    RecoverHealth();
    cut_throat = false;
    cut_torso = false;
    injured_mouth_open = 0.0f;
    this_mo.rigged_object().CleanBlood();
    ClearTemporaryDecals();
    blood_amount = _max_blood_amount;
    recovery_time = 0.0f;
    roll_recovery_time = 0.0f;
    lives = p_lives;
}

void CutThroat() {
    if(!cut_throat){
        string sound = "Data/Sounds/hit/hit_splatter.xml";
        PlaySoundGroup(sound, this_mo.position);

        spurt_sound_delay = _spurt_delay_amount*0.24f;
        cut_throat = true;
        blood_amount = _max_blood_amount;
        last_blood_particle_id = 0;
        SetKnockedOut(_dead);
        Ragdoll(_RGDL_INJURED);
        
        if(GetBloodLevel() != 0){
            mat4 head_transform = this_mo.rigged_object().GetAvgIKChainTransform("head");
            vec3 head_pos = this_mo.rigged_object().GetAvgIKChainPos("head");
            vec3 torso_pos = this_mo.rigged_object().GetAvgIKChainPos("torso");
            vec3 bleed_pos = mix(head_pos, torso_pos, 0.2f);
            head_transform.SetColumn(3, vec3(0.0f));
            float blood_force = sin(time*7.0f)*0.5f+0.5f;
            for(int i=0; i<10; ++i){
                vec3 mist_vel = vec3(RangedRandomFloat(-5.0f,5.0f),RangedRandomFloat(0.0f,5.0f), 0.0f);
                MakeParticle("Data/Particles/bloodcloud.xml",bleed_pos,(head_transform*mist_vel+this_mo.velocity), GetBloodTint());
            } 
        }
    }
}

void SwapWeaponHands() {
    if(weapon_slots[_held_left] == -1 && weapon_slots[_held_right] == -1){
        return;
    }
    if(sheathe_layer_id != -1){
        return;
    }
    int8 flags = 0;
    if(mirrored_stance){
        flags = flags | _ANM_MIRRORED;
    }
    sheathe_layer_id = this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_heldweaponswap.anm",8.0f,flags);
}

// Convert byte colors to float colors (255,0,0) to (1.0f,0.0f,0.0f)
vec3 FloatTintFromByte(const vec3 &in tint){
    vec3 float_tint;
    float_tint.x = tint.x / 255.0f;
    float_tint.y = tint.y / 255.0f;
    float_tint.z = tint.z / 255.0f;
    return float_tint;
}

// Create a random color tint, avoiding excess saturation
vec3 RandReasonableColor(){
    vec3 color;
    color.x = rand()%255;
    color.y = rand()%255;
    color.z = rand()%255;
    float avg = (color.x + color.y + color.z) / 3.0f;
    color = mix(color, vec3(avg), 0.7f);
    return FloatTintFromByte(color);
}

vec3 GetRandomFurColor() {
    vec3 fur_color_byte;
    int rnd = rand()%6;                    
    switch(rnd){
    case 0: fur_color_byte = vec3(255); break;
    case 1: fur_color_byte = vec3(34); break;
    case 2: fur_color_byte = vec3(137); break;
    case 3: fur_color_byte = vec3(105,73,54); break;
    case 4: fur_color_byte = vec3(53,28,10); break;
    case 5: fur_color_byte = vec3(172,124,62); break;
    }
    return FloatTintFromByte(fur_color_byte);
}

void RandomizeColors() {
    Object@ obj = ReadObjectFromID(this_mo.GetID());
    for(int i=0; i<4; ++i){
        const string channel = character_getter.GetChannel(i);
        if(channel == "fur"){
            obj.SetPaletteColor(i, GetRandomFurColor());
        } else if(channel == "cloth"){
            obj.SetPaletteColor(i, RandReasonableColor());
        }
    }
}

string ctrl_key = "ctrl";
string ragdoll_key = "z";
string injured_ragdoll_key = "n";
string cut_throat_key = ",";
string limp_ragdoll_key = "m";
string recover_key = "x";
string path_key = "p";
string scream_key = "v";
string lightning_key = "f";
string combat_rabbit_key = "1";
string civ_rabbit_key = "2";
string cat_key = "3";
string rat_key = "4";
string wolf_key = "5";
string dog_key = "6";
string rabbot_key = "7";
string misc_key = "b";

void HandleSpecialKeyPresses() {
    if(!DebugKeysEnabled() || MPIsConnected){
        return;
    }
    if(GetInputDown(this_mo.controller_id, ragdoll_key) && !GetInputDown(this_mo.controller_id, ctrl_key)){
        GoLimp();
    }
    if(GetInputDown(this_mo.controller_id, injured_ragdoll_key)){                
        if(state != _ragdoll_state){
            string sound = "Data/Sounds/hit/hit_hard.xml";
            PlaySoundGroup(sound, this_mo.position);
        }
        Ragdoll(_RGDL_INJURED);
    }
    if(GetInputPressed(this_mo.controller_id, cut_throat_key)){   
        CutThroat();
    }
    if(GetInputDown(this_mo.controller_id, limp_ragdoll_key)){        
        Ragdoll(_RGDL_LIMP);
    }
    if(GetInputDown(this_mo.controller_id, recover_key)){      
        Recover();
    }

    if(this_mo.controlled){
        if(GetInputDown(this_mo.controller_id, scream_key)){
            string sound = "Data/Sounds/voice/torikamal/fallscream.xml";
            this_mo.ForceSoundGroupVoice(sound, 0.0f);
        }
        if(GetInputPressed(this_mo.controller_id, lightning_key)){
            int num_chars = GetNumCharacters();
            for(int i=0; i<num_chars; ++i){
                MovementObject @char = ReadCharacter(i);
                if(char.getID() == this_mo.getID()){
                    continue;
                }
                vec3 start = this_mo.rigged_object().GetAvgIKChainPos("head");
                vec3 end = char.rigged_object().GetAvgIKChainPos("torso");
                float length = distance(end, start);
                if(length > 10){
                    continue;
                }
                PlaySound("Data/Sounds/ambient/amb_canyon_rock_1.wav", this_mo.position);
                MakeMetalSparks(start);
                MakeMetalSparks(end);
                int num_sparks = int(length * 5);
                for(int j=0; j<num_sparks; ++j){
                    MakeMetalSparks(mix(start, end, j/float(num_sparks)));
                }
                vec3 force = normalize(char.position - this_mo.position) * 40000.0f;
                force.y += 1000.0f;
                char.Execute("vec3 impulse = vec3("+force.x+", "+force.y+", "+force.z+");" +
                             "HandleRagdollImpactImpulse(impulse, this_mo.rigged_object().GetAvgIKChainPos(\"torso\"), 5.0f);"+
                             "ragdoll_limp_stun = 1.0f;"+
                             "recovery_time = 2.0f;");
            }
        }
        if(GetInputPressed(this_mo.controller_id, combat_rabbit_key)){ 
            int rand_int = rand()%3;
            switch(rand_int){
            case 0:
                SwitchCharacter("Data/Characters/guard.xml");
                break;
            case 1:
                SwitchCharacter("Data/Characters/raider_rabbit.xml");
                break;
            case 2:
                SwitchCharacter("Data/Characters/pale_turner.xml");
                break;
            }
        }
        if(GetInputPressed(this_mo.controller_id, civ_rabbit_key)){
            int rand_int = rand()%8;
            switch(rand_int){
            case 0: 
                SwitchCharacter("Data/Characters/male_rabbit_1.xml"); break;
            case 1: 
                SwitchCharacter("Data/Characters/male_rabbit_2.xml"); break;
            case 2: 
                SwitchCharacter("Data/Characters/male_rabbit_3.xml"); break;
            case 3: 
                SwitchCharacter("Data/Characters/female_rabbit_1.xml"); break;
            case 4:
                SwitchCharacter("Data/Characters/female_rabbit_2.xml"); break;
            case 5: 
                SwitchCharacter("Data/Characters/female_rabbit_3.xml"); break;
            case 6: 
            case 7: 
                SwitchCharacter("Data/Characters/pale_rabbit_civ.xml"); break;
            }
        }
        if(GetInputPressed(this_mo.controller_id, cat_key)){
            int rand_int = rand()%4;
            switch(rand_int){
            case 0: 
                SwitchCharacter("Data/Characters/fancy_striped_cat.xml"); break;
            case 1: 
                SwitchCharacter("Data/Characters/female_cat.xml"); break;
            case 2: 
                SwitchCharacter("Data/Characters/male_cat.xml"); break;
            case 3: 
                SwitchCharacter("Data/Characters/striped_cat.xml"); break;
            }
        }
        if(GetInputPressed(this_mo.controller_id, rat_key)){
            int rand_int = rand()%3;
            switch(rand_int){
            case 0: 
                SwitchCharacter("Data/Characters/rat.xml"); break;
            case 1: 
                SwitchCharacter("Data/Characters/hooded_rat.xml"); break;
            case 2: 
                SwitchCharacter("Data/Characters/female_rat.xml"); break;
            }
        }
        if(GetInputPressed(this_mo.controller_id, wolf_key)){
            int rand_int = rand()%6;
            switch(rand_int){
            case 0: 
                SwitchCharacter("Data/Characters/wolf.xml"); break;
            default: 
                SwitchCharacter("Data/Characters/male_wolf.xml"); break;
            }
        }
        if(GetInputPressed(this_mo.controller_id, dog_key)){
            int rand_int = rand()%4;
            switch(rand_int){
            case 0: 
                SwitchCharacter("Data/Characters/lt_dog_big.xml"); break;
            case 1: 
                SwitchCharacter("Data/Characters/lt_dog_female.xml"); break;
            case 2: 
                SwitchCharacter("Data/Characters/lt_dog_male_1.xml"); break;
            case 3: 
                SwitchCharacter("Data/Characters/lt_dog_male_2.xml"); break;
            }
        }
        if(GetInputPressed(this_mo.controller_id, rabbot_key)){
            SwitchCharacter("Data/Characters/rabbot.xml");
        }
        if(GetInputPressed(this_mo.controller_id, misc_key)){
            /*
            int8 flags = _ANM_FROM_START;
            if(mirrored_stance){
                flags = flags | _ANM_MIRRORED;
            }
            flags = flags | _ANM_MOBILE;
            //mirrored_stance = !mirrored_stance;
            this_mo.SetAnimation("Data/Animations/r_hitspinright.anm",20.0f,flags);
            this_mo.rigged_object().anim_client().SetAnimatedItemID(0, weapon_slots[primary_weapon_slot]);
            in_animation = true;
            //throw_anim = true;
            this_mo.rigged_object().anim_client().SetAnimationCallback("void EndAnim()");*/
            //this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_knifethrowlayer.anm",8.0f,0);
            //this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_painflinch.anm",8.0f,0);
            /*if(sheathed_weapon == -1 && held_weapon != -1) {
                //this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_knifesheathe.anm",8.0f,0);
                this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_swordsheathe.anm",8.0f,0);
            } else if(sheathed_weapon != -1 && held_weapon == -1) {
                this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_knifeunsheathe.anm",8.0f,0);
            }*/
            /*int8 flags = _ANM_FROM_START;
            if(weapon_slots[primary_weapon_slot] != -1) {
                this_mo.SetAnimation("Data/Animations/r_swordsheathe.anm",20.0f,flags);
                this_mo.rigged_object().anim_client().SetAnimatedItemID(1, weapon_slots[_sheathed_right]);
            } else if(weapon_slots[primary_weapon_slot] == -1) {
                this_mo.SetAnimation("Data/Animations/r_swordunsheathe.anm",20.0f,flags);
                this_mo.rigged_object().anim_client().SetAnimatedItemID(1, weapon_slots[_sheathed_right_sheathe]);
            }
            in_animation = true;
            this_mo.rigged_object().anim_client().SetAnimationCallback("void EndAnim()");*/
            //
            //SwapWeaponHands();
            
            //CheckPossibleAttacks();
        }
    }
    if(GetInputPressed(this_mo.controller_id, path_key) && target_id != -1){
        Print("Getting path");
        NavPath temp = GetPath(this_mo.position,
                               ReadCharacterID(target_id).position);
        int num_points = temp.NumPoints();
        for(int i=0; i<num_points-1; i++){
            DebugDrawLine(temp.GetPoint(i),
                          temp.GetPoint(i+1),
                          vec3(1.0f,1.0f,1.0f),
                          _fade);
        }
    }
}

vec3 CheckTerminalVelocity(const vec3&in velocity, const Timestep &in ts){
    const float _terminal_velocity = 50.0f;
    const float _terminal_velocity_sqrd = _terminal_velocity*_terminal_velocity;
    if(length_squared(velocity) > _terminal_velocity_sqrd){
        return velocity * pow(0.99f,ts.frames());
    } 
    return velocity;
}

void UnTether() {
    if(tether_id != -1){
        MovementObject @char = ReadCharacterID(tether_id);
        char.Execute("SetTethered(_TETHERED_FREE); SetTetherID(-1);");
        SetTethered(_TETHERED_FREE); 
        SetTetherID(-1);
    }
}

void HandlePlantCollisions(const Timestep &in ts){
    in_plant = 0.0f;
    {
        vec3 offset;
        vec3 scale;
        float size;
        GetCollisionSphere(offset, scale, size);
        scale.x *= 0.5f;
        scale.z *= 0.5f;
        col.GetScaledSpherePlantCollision(this_mo.position+offset, size*0.2f, scale);
        if(sphere_col.NumContacts() != 0){
            in_plant += 0.25f;
        }
        col.GetScaledSpherePlantCollision(this_mo.position+offset, size*0.4f, scale);
        if(sphere_col.NumContacts() != 0){
            in_plant += 0.25f;
        }
        col.GetScaledSpherePlantCollision(this_mo.position+offset, size*0.6f, scale);
        if(sphere_col.NumContacts() != 0){
            in_plant += 0.25f;
        }
        col.GetScaledSpherePlantCollision(this_mo.position+offset, size*0.8f, scale);
        if(sphere_col.NumContacts() != 0){
            in_plant += 0.25f;
        }
        col.GetScaledSpherePlantCollision(this_mo.position+offset, size, scale);
        /*vec3 color;
        if(in_plant == 0.0f){ 
            color = vec3(0.0f,1.0f,0.3f);
        } else {
            color = vec3(1.0f,0.0f,0.0f);
        }
        DebugDrawWireScaledSphere(this_mo.position+offset,size,scale,color,_delete_on_update);
        if(in_plant < 1.0f){ 
            color = vec3(0.0f,1.0f,0.3f);
        } else {
            color = vec3(1.0f,0.0f,0.0f);
        }
        DebugDrawWireScaledSphere(this_mo.position+offset,size*0.2f,scale,color,_delete_on_update);
        if(in_plant < 0.75f){ 
            color = vec3(0.0f,1.0f,0.3f);
        } else {
            color = vec3(1.0f,0.0f,0.0f);
        }
        DebugDrawWireScaledSphere(this_mo.position+offset,size*0.4f,scale,color,_delete_on_update);
        if(in_plant < 0.5f){ 
            color = vec3(0.0f,1.0f,0.3f);
        } else {
            color = vec3(1.0f,0.0f,0.0f);
        }
        DebugDrawWireScaledSphere(this_mo.position+offset,size*0.6f,scale,color,_delete_on_update);
        if(in_plant < 0.25f){ 
            color = vec3(0.0f,1.0f,0.3f);
        } else {
            color = vec3(1.0f,0.0f,0.0f);
        }
        DebugDrawWireScaledSphere(this_mo.position+offset,size*0.8f,scale,color,_delete_on_update);*/
    }
    array<int> plant_ids;
    {
        bool already_known_plant;
        for(int i=0; i<sphere_col.NumContacts(); i++){
            const CollisionPoint contact = sphere_col.GetContact(i);
            //DebugDrawWireSphere(contact.position, 0.1f, vec3(1.0f), _delete_on_update);
            already_known_plant = false;
            for(uint j=0; j<plant_ids.size(); ++j){
                if(plant_ids[j] == contact.id){
                    already_known_plant = true;
                }
            }
            if(!already_known_plant){
                plant_ids.push_back(contact.id);
            }
        }
    }
    float speed = length_squared(this_mo.velocity);
    if(in_plant > 0.25f){
        int plant = rand()%plant_ids.size();
        SendMessage(plant_ids[plant], _plant_movement_msg, this_mo.position, this_mo.velocity);
        EnvObject@ eo = ReadEnvObjectID(plant_ids[plant]);
        for(int j=0; j<3; ++j){
            if(RangedRandomFloat(0.0f,100.0f) < speed){
                eo.CreateLeaf(this_mo.position, this_mo.velocity * 0.8f, 10);
            }
            if(RangedRandomFloat(0.0f,100.0f) < speed){
                eo.CreateLeaf(vec3(0.0f),vec3(0.0f),1);
            }
        }
    }
    plant_rustle_delay = max(0.0f, plant_rustle_delay-ts.step());
    if(plant_rustle_delay <= 0.0f && in_plant > 0.5f){
        if(speed > 3.0f){   
            plant_rustle_delay = 0.7f;
            string sound;
            //Print("Speed: "+speed+"\n");
            if(speed < 15.0f){
                sound = "Data/Sounds/plant_foley/bush_slow.xml";
                //Print("Slow\n");
            } else if(speed > 70.0f){
                sound = "Data/Sounds/plant_foley/bush_fast.xml";
                //Print("Fast\n");
            } else {
                sound = "Data/Sounds/plant_foley/bush_medium.xml";
                //Print("Medium\n");
            }
            this_mo.PlaySoundGroupAttached(sound,this_mo.position);
        }
    }
    if(in_plant > 0.0f && !on_ground && !flip_info.IsFlipping()){
        this_mo.velocity.x *= pow(0.97f, ts.frames()*in_plant);
        this_mo.velocity.z *= pow(0.97f, ts.frames()*in_plant);
        if(this_mo.velocity.y > 0.0f){
            this_mo.velocity.y *= pow(0.97f, ts.frames()*in_plant);
        }
        if(speed > 110.0f){
            GoLimp();
        }
    }
}


//int plant_flinch_layer = -1;
void UpdatePlantAvoid() {
    /*if(plant_flinch_layer == -1 && in_plant != 0.0f){
        Print("Adding plant avoid\n");
        plant_flinch_layer = 
            this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_plantavoid.anm",4.0f,0);
    } 
    if(in_plant == 0.0f && plant_flinch_layer != -1){
        this_mo.rigged_object().anim_client().RemoveLayer(plant_flinch_layer, 4.0f);
        plant_flinch_layer = -1;
    }*/
}


void UpdateState(const Timestep &in ts) {
    cam_pos_offset = vec3(0.0f);
    UpdateEyeLookTarget();
    UpdateHeadLook(ts);
    UpdateBlink(ts);

    UpdatePlantAvoid();
    UpdateActiveBlockAndDodge(ts);
    RegenerateHealth(ts);

    trying_to_get_weapon = max(0,trying_to_get_weapon-1);

     if(state == _ragdoll_state){ // This is not part of the else chain because
        UpdateRagDoll(ts);         // the character may wake up and need other
        HandlePickUp();          // state updates
    } 
    
    use_foot_plants = false;

    UpdateThreatAmount(ts);
    UpdateIdleType();

    switch(state){
    case _movement_state:
        UpdateDuckAmount(ts);
        UpdateGroundAndAirTime(ts);
        HandleAccelTilt(ts);
        CheckForStartBodyDrag();
        UpdateMovementControls(ts);
        UpdateAnimation(ts);
        ApplyPhysics(ts);
        HandlePickUp();
        HandleThrow();
        HandleCollisions(ts);
        break;
    case _ground_state:
        UpdateDuckAmount(ts);
        HandleAccelTilt(ts);
        UpdateGroundState(ts);
        break;
    case _attack_state:
        HandleAccelTilt(ts);
        UpdateAttacking(ts);
        HandleCollisions(ts);
        break;
    case _hit_reaction_state:
        if(active_block_anim && hit_reaction_time > 0.1f){
            UpdateGroundAttackControls(ts);
        } 
        UpdateHitReaction(ts);
        HandleThrow();
        HandleAccelTilt(ts);
        HandleCollisions(ts);
        break;
    }
    
    HandlePlantCollisions(ts);

    old_use_foot_plants = use_foot_plants;
    if(!use_foot_plants && foot.length() != 0){
        for(int i=0; i<2; ++i){
            foot[i].pos *= 0.9f;
            foot[i].height *= 0.9f;
        }
    }

    HandleTethering(ts);

    this_mo.velocity = CheckTerminalVelocity(this_mo.velocity, ts);   

    UpdateTilt(ts);
    
    if(on_ground && state == _movement_state){
        DecalCheck();
    }
    left_smear_time += ts.step();
    right_smear_time += ts.step();
    smear_sound_time += ts.step();
}

void UpdateIdleType() {
    bool needs_combat_pose = NeedsCombatPose();
    if(needs_combat_pose){
        combat_stance_time = time;
    }
    if(combat_stance_time > time-2.0f){
        idle_type = _combat;
    } else if(WantsReadyStance()){
        idle_type = _active;
    } else {
        idle_type = _stand;
    }
}

int GetCharPrimaryWeapon(MovementObject@ mo){
    return mo.GetArrayIntVar("weapon_slots",mo.GetIntVar("primary_weapon_slot"));
}

void HandleTethering(const Timestep &in ts) {    
    if(tethered == _TETHERED_REARCHOKE){
        MovementObject @char = ReadCharacterID(tether_id);
        // Let go if necessary
        if((!WantsToThrowEnemy() || abs(this_mo.position.y - char.position.y) > _max_tether_height_diff) && !executing){
            UnTether();
            return;
        }
        // Enforce relative position
        if(tether_id != -1 && state == _movement_state){
            vec3 rel = char.position - this_mo.position;
            rel.y = 0.0f;
            rel = normalize(rel);
            tether_rel = mix(rel, tether_rel, pow(0.1f, ts.frames()));
            vec3 mid_point = (char.position + this_mo.position)*0.5f;
            vec3 old_pos0;
            vec3 old_pos1;
            old_pos0 = this_mo.position;
            old_pos1 = char.position;
            char.position = mix(char.position, mid_point + tether_rel*tether_dist*0.5f, 1.0f);
            this_mo.position = mix(this_mo.position, mid_point - tether_rel*tether_dist*0.5f, 1.0f);
            this_mo.position.y = old_pos0.y;
            char.position.y = old_pos1.y;
            this_mo.velocity += (this_mo.position - old_pos0)/(ts.step());
            char.velocity += (char.position - old_pos1)/(ts.step());
            char.SetRotationFromFacing(tether_rel);
            this_mo.SetRotationFromFacing(tether_rel);

            //DebugDrawWireSphere(char.rigged_object().GetAvgIKChainPos("head"), 0.1f, vec3(1.0f), _delete_on_update);
            //DebugDrawWireSphere(this_mo.rigged_object().GetAvgIKChainPos("torso"), 0.1f, vec3(1.0f), _delete_on_update);
            /*mat4 torso_transform = this_mo.rigged_object().GetAvgIKChainTransform("torso");
            Print("Vec: ");
            PrintVec3(invert(torso_transform)*char.rigged_object().GetAvgIKChainPos("head"));
            Print("\n");
            vec3 target_offset = vec3(-0.1f, 0.2f, 0.3f);
            DebugDrawWireSphere(torso_transform * target_offset, 0.1f, vec3(1.0f), _delete_on_update);
*/
            float avg_duck = duck_amount;
            avg_duck += char.GetFloatVar("duck_amount");
            avg_duck *= 0.5f;
            duck_amount = avg_duck;
            char.Execute("duck_amount = "+avg_duck+";");
        }
    }
    if(tethered == _TETHERED_REARCHOKED){
        DropWeapon();
        // Choking        
        MovementObject@ char = ReadCharacterID(tether_id);
        int weap_id = GetCharPrimaryWeapon(char);
        if(weap_id == -1){
            TakeDamage(ts.step() * 0.25f);
            if(knocked_out != _awake){
                this_mo.MaterialEvent("choke_fall", this_mo.position);
                int other_char_id = tether_id;
                Ragdoll(_RGDL_LIMP);
                ReadCharacterID(other_char_id).Execute("ChokedOut(" + this_mo.getID() + ");");
            }
        }
    }
    if(tethered == _TETHERED_DRAGBODY){
        if(!WantsToDragBody()){
            UnTether();
            return;
        }
        MovementObject@ char = ReadCharacterID(tether_id);
        if(char.GetIntVar("state") != _ragdoll_state){
            UnTether();
            return;
        }
        vec3 arm_pos = GetDragOffsetWorld();
        vec3 head_pos = char.rigged_object().GetIKChainPos(drag_body_part,drag_body_part_id);
        vec3 arm_pos_flat = vec3(arm_pos.x, 0.0f, arm_pos.z);
        vec3 head_pos_flat = vec3(head_pos.x, 0.0f, head_pos.z);
        float dist = distance(arm_pos_flat, head_pos_flat);
        if(dist > 0.2f){
            this_mo.velocity += (normalize(head_pos_flat - arm_pos_flat) * (dist - 0.2f)) * 5.0f * drag_strength_mult;            
        }
        if(drag_strength_mult > 0.3f){
            drag_target = mix(arm_pos, drag_target, pow(0.95f, ts.frames()));
            char.rigged_object().MoveRagdollPart(drag_body_part,drag_target,drag_strength_mult);
        } else {
            drag_target = head_pos;
        }
        char.Execute("RagdollRefresh(1);");
        
        float old_drag_strength_mult = drag_strength_mult;
        drag_strength_mult = mix(1.0f, drag_strength_mult, pow(0.95f,ts.frames()));
        if(old_drag_strength_mult < 0.7f && drag_strength_mult >= 0.7f){
            PlaySoundGroup("Data/Sounds/hit/grip.xml", this_mo.position);
        }
        //DebugDrawWireSphere(head_pos,0.2f, vec3(1.0f), _delete_on_update);
        tether_rel = char.position - this_mo.position;
        tether_rel.y = 0.0f;
        tether_rel = normalize(tether_rel);
        this_mo.SetRotationFromFacing(InterpDirections(this_mo.GetFacing(),tether_rel,1.0 - pow(0.95f, ts.frames())));
    }
}

void UpdateTilt(const Timestep &in ts) {
    const float _tilt_inertia = 0.9f;
    tilt = tilt * pow(_tilt_inertia,ts.frames()) +
           target_tilt * (1.0f - pow(_tilt_inertia,ts.frames()));
    tilt_modifier = tilt;
}

vec3 run_eye_look_target;
vec3 eye_look_target;
vec3 random_look_target;

void UpdateEyeLookTarget() {
    if(tethered == _TETHERED_REARCHOKED){
        // Look around randomly if being choked
        if(time >= choke_look_time){
            vec3 dir = vec3(RangedRandomFloat(-1.0f, 1.0f),
                            RangedRandomFloat(-0.2f, 0.2f),
                            RangedRandomFloat(-1.0f, 1.0f));
            eye_look_target = this_mo.position + dir * 100.0f;
            choke_look_time = time + RangedRandomFloat(0.1f,0.3f);
        }
    } else if(trying_to_get_weapon != 0){
        // Look at weapon if trying to get it
        eye_look_target = get_weapon_pos;
    } else {
        // Look at throw target
        if(throw_knife_layer_id != -1 && target_id != -1){
            force_look_target_id = target_id;
        }
        if(force_look_target_id != -1){
            vec3 target_pos = ReadCharacterID(force_look_target_id).rigged_object().GetAvgIKChainPos("head");
            eye_look_target = target_pos;
        } else if(this_mo.controlled){
            vec3 dir_flat = camera.GetFacing();
            eye_look_target = this_mo.position + camera.GetFacing() * 100.0f;
        } else {
            if(look_target.type == _none){
                eye_look_target = random_look_target;
            } else if(look_target.type == _character){
                vec3 target_pos = ReadCharacterID(look_target.id).rigged_object().GetAvgIKChainPos("head");
                eye_look_target = target_pos;
            }
        }
    }

    if(state == _movement_state && stance_move_fade != 1.0f){
        if(on_ground && length_squared(GetTargetVelocity())>0.0f){// && sin(time*3.0f)+sin(time*2.3f)>0.0f){
            eye_look_target = run_eye_look_target;
        } else if(!on_ground){
            vec3 vel_facing = this_mo.velocity + this_mo.GetFacing() * 2.0f;
            eye_look_target.x = this_mo.position.x + vel_facing.x * 30.0f;
            eye_look_target.z = this_mo.position.z + vel_facing.z * 30.0f;
            eye_look_target.y = this_mo.position.y + vel_facing.y * 5.0f;
        }
    }

    if(time >= random_look_delay){
        random_look_delay = time + RangedRandomFloat(0.8f,2.0f);
        vec3 rand_dir;
        do {
            rand_dir = vec3(RangedRandomFloat(-1.0f,1.0f),
                            0.0f,
                            RangedRandomFloat(-1.0f,1.0f));
        } while(length_squared(rand_dir) > 1.0f);
        if(dot(this_mo.GetFacing(), rand_dir) < 0.0f){
            rand_dir *= -1.0f;
        }
        rand_dir = normalize(rand_dir);
        rand_dir.y += RangedRandomFloat(-0.3f,0.3f);
        random_look_dir = normalize(rand_dir);
        random_look_dir = mix(this_mo.GetFacing(), random_look_dir, 0.5f);
        random_look_target = this_mo.position + random_look_dir * 100.0f;
        situation.GetLookTarget(look_target);
    }
}

vec3 head_look;
vec3 torso_look;

void UpdateHeadLook(const Timestep &in ts) {
    vec3 head_eye_dir = normalize(eye_look_target - this_mo.rigged_object().GetAvgIKChainPos("head")); //GetTargetHeadDir(ts);
    vec3 head_dir = head_eye_dir;

    const bool _draw_gaze_line = false;
    if(_draw_gaze_line){
        vec3 head_pos = this_mo.rigged_object().GetAvgIKChainPos("head");
        DebugDrawLine(head_pos, head_pos + head_dir, vec3(1.0f,0.0f,0.0f), _fade);
    }

    float target_head_look_opac = 1.0f;
    if((state == _attack_state && attacking_with_throw != 0) ||
        tethered == _TETHERED_REARCHOKE || tethered == _TETHERED_DRAGBODY)
    {
        target_head_look_opac = 0.0f;
    }

    head_look_opac = target_head_look_opac;
    head_look_opac *= max(0.0f, (1.0f - flip_ik_fade));
    head_look = head_dir * head_look_opac;

    if((state != _movement_state && state != _attack_state) || flip_info.IsFlipping()){
        head_look = vec3(0.0f);
    }

    if(block_flinch_spring.value > 0.1f){
        head_look *= min(1.0f, 1.0f - block_flinch_spring.value*0.5f);
    }
    
    if(!stance_move){
        stance_move_fade_val = mix(stance_move_fade,stance_move_fade_val,pow(0.9f,ts.frames()));
    } else {
        stance_move_fade_val = mix(0.5f,stance_move_fade_val,pow(0.9f,ts.frames()));
    }
    if(state != _movement_state || flip_info.IsFlipping()){
        stance_move_fade_val = 0.0f;
    }
    vec3 flat_head_dir = head_dir;
    flat_head_dir.y = 0.0f;
    flat_head_dir = normalize(flat_head_dir);
    float torso_control = 1.0f;
    torso_control *= max(0.35f,stance_move_fade_val);
    torso_control = min(head_look_opac, torso_control);
    if(IsLayerAttacking()){
        layer_attacking_fade = mix(1.0f, layer_attacking_fade, pow(0.9f, ts.frames()));
    } else {
        layer_attacking_fade = mix(0.0f, layer_attacking_fade, pow(0.95f, ts.frames()));
    }
    torso_control *= (1.0f - layer_attacking_fade);
    torso_control *= (1.0f - duck_amount * 0.5f);
    
    if(throw_knife_layer_id != -1){
        layer_throwing_fade = mix(1.0f, layer_attacking_fade, pow(0.9f, ts.frames()));
    } else {
        layer_throwing_fade = mix(0.0f, layer_attacking_fade, pow(0.95f, ts.frames()));
    }
    torso_control = mix(torso_control,0.5f,layer_throwing_fade);
    if(ledge_info.on_ledge || !on_ground || state != _movement_state){
        torso_control = 0.0f;
    }

    torso_look = head_dir*torso_control;

    stance_move_fade = max(0.0f, stance_move_fade - ts.step());
}

void SetEyeLookDir(const vec3 &in eye_dir) {
    // Set weights for carnivore
    this_mo.rigged_object().SetMorphTargetWeight("look_r",max(0.0f,eye_dir.x),1.0f);
    this_mo.rigged_object().SetMorphTargetWeight("look_l",max(0.0f,-eye_dir.x),1.0f);
    this_mo.rigged_object().SetMorphTargetWeight("look_u",max(0.0f,eye_dir.y),1.0f);
    this_mo.rigged_object().SetMorphTargetWeight("look_d",max(0.0f,-eye_dir.y),1.0f);

    // Set weights for herbivore
    this_mo.rigged_object().SetMorphTargetWeight("look_u",max(0.0f,eye_dir.y),1.0f);
    this_mo.rigged_object().SetMorphTargetWeight("look_d",max(0.0f,-eye_dir.y),1.0f);
    this_mo.rigged_object().SetMorphTargetWeight("look_f",max(0.0f,eye_dir.z),1.0f);
    this_mo.rigged_object().SetMorphTargetWeight("look_b",max(0.0f,-eye_dir.z),1.0f);

    // Set weights for independent-eye herbivore
    this_mo.rigged_object().SetMorphTargetWeight("look_u_l",max(0.0f,eye_dir.y),1.0f);
    this_mo.rigged_object().SetMorphTargetWeight("look_u_r",max(0.0f,eye_dir.y),1.0f);
    this_mo.rigged_object().SetMorphTargetWeight("look_d_l",max(0.0f,-eye_dir.y),1.0f);
    this_mo.rigged_object().SetMorphTargetWeight("look_d_r",max(0.0f,-eye_dir.y),1.0f);

    float right_front = eye_dir.z;
    float left_front = eye_dir.z;
    this_mo.rigged_object().SetMorphTargetWeight("look_f_r",max(0.0f,right_front),1.0f);
    this_mo.rigged_object().SetMorphTargetWeight("look_b_r",max(0.0f,-right_front),1.0f);
    this_mo.rigged_object().SetMorphTargetWeight("look_f_l",max(0.0f,left_front),1.0f);
    this_mo.rigged_object().SetMorphTargetWeight("look_b_l",max(0.0f,-left_front),1.0f);
}

enum WhichEye {
    kLeftEye,
    kRightEye
}

bool GetEyeDir(WhichEye which_eye, const string &in morph_label, vec3 &out start, vec3 &out end) {
    if(character_getter.GetMorphMetaPoints(morph_label, start, end)){
        if(which_eye == kLeftEye){
            start.x *= -1.0f;
            end.x *= -1.0f;
        }
        Skeleton @skeleton = this_mo.rigged_object().skeleton();
        BoneTransform test = skeleton_bind_transforms[skeleton.IKBoneStart("head")];
        float temp;
        vec3 model_center = this_mo.rigged_object().GetModelCenter();
        temp = start.z;
        start.z = -start.y;
        start.y = temp;
        temp = end.z;
        end.z = -end.y;
        end.y = temp;
        start -= model_center;
        end -= model_center;
        start = test * start;
        end = test * end;
        return true;
    } else {
        return false;
    }
}

array<int> debug_eye_lines;
vec3 eye_offset;
float eye_offset_time = 0.0f;

void UpdateEyeLook(){
    // Clear debug lines
    for(int i=0, len=debug_eye_lines.size(); i<len; ++i){
        DebugDrawRemove(debug_eye_lines[i]);
    }
    debug_eye_lines.resize(0);

    if(knocked_out != _awake){
        return;
    }

    vec3 target_pos = eye_look_target;// vec3(sin(time*1.4f),1.0f+sin(time*1.2f),1.0f);
    BoneTransform head_mat = this_mo.rigged_object().GetFrameMatrix(ik_chain_elements[ik_chain_start_index[kHeadIK]]);
    vec3 temp_target_pos = normalize(invert(head_mat) * target_pos);
    
    string species = character_getter.GetTag("species");
    vec3 base_start, base_end;
    WhichEye which_eye = kRightEye;
    bool valid = GetEyeDir(kRightEye, "look_c", base_start, base_end);
    if(valid){
        eye_dir = 0;
        if(species == "rabbit" || species == "rat"){
            /*float right_eye_dot = dot(base_end-base_start, temp_target_pos-base_start);
            GetEyeDir(kLeftEye, "look_c", base_start, base_end);
            float left_eye_dot = dot(base_end-base_start, temp_target_pos-base_start);
            if(left_eye_dot > right_eye_dot){
                which_eye = kLeftEye;
            }*/
            if((invert(head_mat) * camera.GetPos()).x<0.0f){
                which_eye = kLeftEye;
            }
            GetEyeDir(which_eye, "look_c", base_start, base_end);
        }

        //debug_eye_lines.push_back(DebugDrawLine(head_mat * base_start, target_pos, 1.0f, vec3(1.0f), _fade));
        //debug_eye_lines.push_back(DebugDrawLine(head_mat * base_start, head_mat * temp_target_pos, 1.0f, vec3(1.0f), _fade));
        //debug_eye_lines.push_back(DebugDrawLine(head_mat * base_start, head_mat * base_end, 1.0f, vec3(1.0f), _fade));
        
        vec3 start1, end1, start2, end2;
        {
            GetEyeDir(which_eye, "look_u", start1, end1);
            GetEyeDir(which_eye, "look_d", start2, end2);
            vec3 normal = normalize(cross(end2-base_start, end1-base_start));
            vec3 test_targ = temp_target_pos - normal * dot(normal, temp_target_pos);
            vec3 neutral_dir = normalize(base_end - base_start);
            vec3 normal2 = normalize(cross(normal, neutral_dir));
            float up_angle = asin(dot(normalize(end1-start1), normal2));
            float down_angle = asin(dot(normalize(end2-start2), normal2));
            float targ_angle = asin(dot(normalize(test_targ-base_start), normal2));
            if(targ_angle > 0.0f){
                eye_dir.y = min(1.0f, targ_angle / up_angle);
            } else {
                eye_dir.y = -min(1.0f, targ_angle / down_angle);            
            }
        }
        if(species == "rabbit" || species == "rat"){
            GetEyeDir(which_eye, "look_f", start1, end1);
            GetEyeDir(which_eye, "look_b", start2, end2);
            vec3 normal = normalize(cross(end2-base_start, end1-base_start));
            vec3 test_targ = temp_target_pos - normal * dot(normal, temp_target_pos);
            vec3 neutral_dir = normalize(base_end - base_start);
            vec3 normal2 = normalize(cross(normal, neutral_dir));
            float front_angle = asin(dot(normalize(end1-start1), normal2));
            float back_angle = asin(dot(normalize(end2-start2), normal2));
            float targ_angle = asin(dot(normalize(test_targ-base_start), normal2));
            if(targ_angle > 0.0f){
                eye_dir.z = min(1.0f, targ_angle / front_angle);
            } else {
                eye_dir.z = -min(1.0f, targ_angle / back_angle);            
            }
        } else {
            GetEyeDir(which_eye, "look_l", start1, end1);
            GetEyeDir(which_eye, "look_r", start2, end2);
            vec3 normal = normalize(cross(end2-base_start, end1-base_start));
            vec3 test_targ = temp_target_pos - normal * dot(normal, temp_target_pos);
            vec3 neutral_dir = normalize(base_end - base_start);
            vec3 normal2 = normalize(cross(normal, neutral_dir));
            float front_angle = asin(dot(normalize(end1-start1), normal2));
            float back_angle = asin(dot(normalize(end2-start2), normal2));
            float targ_angle = asin(dot(normalize(test_targ-base_start), normal2));
            if(targ_angle > 0.0f){
                eye_dir.x = -min(1.0f, targ_angle / front_angle);
            } else {
                eye_dir.x = min(1.0f, targ_angle / back_angle);            
            }
        }

        bool draw_eye_line = false;
        if(draw_eye_line) {
            vec3 temp_base_start, temp_base_end;
            GetEyeDir(which_eye, "look_c", temp_base_start, temp_base_end);
            vec3 offset_start, offset_end;
            vec3 start, end;
            if(eye_dir.y > 0.0f){
                GetEyeDir(which_eye, "look_u", start, end);
                offset_start += (start-temp_base_start)*eye_dir.y;
                offset_end += (end-temp_base_end)*eye_dir.y;
            }
            if(eye_dir.y < 0.0f){
                GetEyeDir(which_eye, "look_d", start, end);
                offset_start += (start-temp_base_start)*-eye_dir.y;
                offset_end += (end-temp_base_end)*-eye_dir.y;
            }
            if(species == "rabbit" || species == "rat"){
                if(eye_dir.z < 0.0f){
                    GetEyeDir(which_eye, "look_b", start, end);
                    offset_start += (start-temp_base_start)*-eye_dir.z;
                    offset_end += (end-temp_base_end)*-eye_dir.z;
                }
                if(eye_dir.z > 0.0f){
                    GetEyeDir(which_eye, "look_f", start, end);
                    offset_start += (start-temp_base_start)*eye_dir.z;
                    offset_end += (end-temp_base_end)*eye_dir.z;
                }
            } else {
                if(eye_dir.x < 0.0f){
                    GetEyeDir(which_eye, "look_l", start, end);
                    offset_start += (start-temp_base_start)*-eye_dir.x;
                    offset_end += (end-temp_base_end)*-eye_dir.x;
                }
                if(eye_dir.x > 0.0f){
                    GetEyeDir(which_eye, "look_r", start, end);
                    offset_start += (start-temp_base_start)*eye_dir.x;
                    offset_end += (end-temp_base_end)*eye_dir.x;
                }
            }
            debug_eye_lines.push_back(DebugDrawLine(head_mat * (temp_base_start + offset_start), head_mat * (temp_base_end+offset_end), 1.0f, vec3(1.0f), _fade));
        }
    }

    if(eye_offset_time < time){
        eye_offset = vec3(RangedRandomFloat(-0.2f,0.2f),
                        RangedRandomFloat(-0.2f,0.2f),
                        RangedRandomFloat(-0.2f,0.2f));
        eye_offset_time = time + RangedRandomFloat(0.2f,1.0f);
    }

    SetEyeLookDir(eye_dir + eye_offset);
}

float last_resting_blink_change = 0.0f;
float resting_blink = 0.0f;
float target_resting_blink = 0.0f;

void UpdateBlink(const Timestep &in ts) {
    const float _blink_speed = 5.0f;
    const float _blink_min_delay = 1.0f;
    const float _blink_max_delay = 5.0f;

    float final_blink = blink_amount;
    if(knocked_out == _awake){
        if(blink_delay < 0.0f){
            blink_delay = RangedRandomFloat(_blink_min_delay,
                                            _blink_max_delay);
            blinking = true;
            blink_progress = 0.0f;
        }
        if(blinking){
            blink_progress += ts.step() * 5.0f;
            blink_amount = sin(blink_progress*3.14f);
            if(blink_progress > 1.0f){
                blink_amount = 0.0f;
                blinking = false;
            }
        } else {
            blink_amount = 0.0f;
        }
        blink_delay -= ts.step();
        if(last_resting_blink_change < time) {
            target_resting_blink = RangedRandomFloat(0.8f,1.0f);
            last_resting_blink_change = time + RangedRandomFloat(0.4f,0.7f);
        }
        resting_blink = mix(target_resting_blink, resting_blink, pow(0.9f, ts.frames()));
        final_blink = 1.0f-((1.0f-blink_amount) * blink_mult);
        final_blink = 1.0f - (1.0f - final_blink) * resting_blink;
    } else if(knocked_out == _unconscious){
        blink_amount = mix(blink_amount, 0.9f, 0.1f);
    }
    this_mo.rigged_object().SetMorphTargetWeight("wink_r",final_blink,1.0f);
    this_mo.rigged_object().SetMorphTargetWeight("wink_l",final_blink,1.0f);
}

class Spring {
    float value, target_value, velocity, damping, stiffness;
    Spring(float _damping, float _stiffness){
        damping = _damping;
        stiffness = _stiffness;
        target_value = 0.0f;
        value = 0.0f;
        velocity = 0.0f;
    }
    void Update(const Timestep &in ts) {
        velocity += (target_value - value) * ts.step() * stiffness;
        value += velocity * ts.step();
        velocity *= pow(damping, ts.frames());
    }
}

Spring block_flinch_spring(0.9f, 0.9f);

void UpdateActiveBlockAndDodge(const Timestep &in ts) {
    block_stunned = max(0.0f, block_stunned - ts.step());

    if(tethered == _TETHERED_FREE){
        UpdateActiveBlockMechanics(ts);
        UpdateActiveDodgeMechanics(ts);
    }
    if(active_block_time > time - 0.3f){
        block_flinch_spring.stiffness = 300.0f;
        block_flinch_spring.target_value = 1.0f;
        block_flinch_spring.damping = 0.8f;
    } else {
        block_flinch_spring.stiffness = 150.0f;
        block_flinch_spring.damping = 0.86f;
        block_flinch_spring.target_value = 0.0f;
    }
    block_flinch_spring.Update(ts);
    //block_flinch_spring.value = sin(time);
    if(abs(block_flinch_spring.value) < 0.01f && abs(block_flinch_spring.velocity) < 0.01f){
        if(active_block_flinch_layer != -1){
            this_mo.rigged_object().anim_client().RemoveLayer(active_block_flinch_layer, 4.0f);
            active_block_flinch_layer = -1;
        }
    } else {
        if(active_block_flinch_layer == -1 && state != _hit_reaction_state) {            
            int8 flags = 0;
            if(mirrored_stance){
                flags |= _ANM_MIRRORED;
            }
            active_block_flinch_layer = this_mo.rigged_object().anim_client().AddLayer(character_getter.GetAnimPath("blockflinch"),10.0f,flags);
        }
    }
    if(active_block_flinch_layer != -1) {            
        this_mo.rigged_object().anim_client().SetLayerOpacity(active_block_flinch_layer, block_flinch_spring.value);
    }
}


bool CanBlock(){
    if(knocked_out != _awake){
        return false;
    }
    if(state == _movement_state || 
       state == _ragdoll_state ||
       state == _ground_state ||
      (state == _hit_reaction_state && !hit_reaction_thrown) ||
      (state == _attack_state && block_stunned > 0.0f)){
        if(!on_ground || flip_info.IsFlipping()){
            return false;
        } else {
            return true;
        }
    } else {
        return false;
    }
}

float active_block_time = -10.0f;

void UpdateActiveBlockMechanics(const Timestep &in ts) {
    bool can_block = CanBlock();
    if(WantsToStartActiveBlock(ts) && can_block){
        if(active_block_recharge <= 0.0f){
            active_block_time = time;
            active_blocking = true;
            active_block_duration = 0.2f;
        }
        active_block_recharge = 0.2f;
    } 
    if(active_blocking){
        active_block_duration -= ts.step();
        if(active_block_duration <= 0.0f){
            active_blocking = false;
        }
    } else {
        if(active_block_recharge > 0.0f){
            active_block_recharge -= ts.step();
        }
    }
}

void UpdateActiveDodgeMechanics(const Timestep &in ts) {
    bool can_dodge = CanBlock();
    if(WantsToDodge(ts) && can_dodge){
        if(active_dodge_recharge <= 0.0f){
            active_dodging = true;
            active_dodge_duration = 0.2f;
            dodge_dir = GetDodgeDirection();
        }
        active_dodge_recharge = 0.2f;
    } 
    if(active_dodging){
        active_dodge_duration -= ts.step();
        if(active_dodge_duration <= 0.0f){
            active_dodging = false;
        }
    } else {
        if(active_dodge_recharge > 0.0f){
            active_dodge_recharge -= ts.step();
        }
    }
}

void RegenerateHealth(const Timestep &in ts) {
    const float _block_recover_speed = 0.3f;
    const float _temp_health_recover_speed = 0.05f;
    block_health += _block_recover_speed * ts.step();
    block_health = min(temp_health, block_health);
    temp_health += _temp_health_recover_speed * ts.step();
    temp_health = min(permanent_health, temp_health);
    if(blood_damage > 0.0f){
        float damage = min(time_step, blood_damage);
        blood_damage -= damage;
        blood_health -= damage;
        if(blood_health <= 0.0f && knocked_out == _awake){
            SetKnockedOut(_unconscious);
            Ragdoll(_RGDL_LIMP);
        }
    }
}

void UpdateRagDoll(const Timestep &in ts) {
    ragdoll_time += ts.step();
    ragdoll_limp_stun -= ts.step();
    ragdoll_limp_stun = max(0.0, ragdoll_limp_stun);

    if(!frozen){
        switch(ragdoll_type){
            case _RGDL_FALL:
                SetActiveRagdollFallPose();
                break;
            case _RGDL_INJURED:
                SetActiveRagdollInjuredPose();
                break;
        }
        
        UpdateRagdollDamping(ts);
    }
    
    if(knocked_out == _awake){
        HandleRagdollRecovery(ts);
    }
    /*
    mat4 torso_transform = this_mo.rigged_object().GetAvgIKChainTransform("torso");
    vec3 torso_vec = torso_transform.GetColumn(1);//(torso_transform * vec4(0.0f,0.0f,1.0f,0.0));
    //Print(""+torso_vec.x +" "+torso_vec.y+" "+torso_vec.z+"\n");
    DebugDrawLine(this_mo.position,
                  this_mo.position + torso_vec,
                  vec3(1.0f),
                  _delete_on_update);
    torso_vec = torso_transform.GetColumn(2);//(torso_transform * vec4(0.0f,0.0f,1.0f,0.0));
    //Print(""+torso_vec.x +" "+torso_vec.y+" "+torso_vec.z+"\n");
    DebugDrawLine(this_mo.position,
                  this_mo.position + torso_vec,
                  vec3(1.0f),
                  _delete_on_update);*/
}

void RagdollRefresh(int val){
    ragdoll_static_time = 0.0f;
    frozen = false;
    this_mo.rigged_object().SetRagdollDamping(0.0f);
    this_mo.rigged_object().RefreshRagdoll();
}

void UpdateRagdollDamping(const Timestep &in ts) {
    const float _ragdoll_static_threshold = 0.4f; // Velocity below which ragdoll is considered static

    if(length(this_mo.rigged_object().GetAvgVelocity())<_ragdoll_static_threshold){
        ragdoll_static_time += ts.step();
    } else {
        ragdoll_static_time = 0.0f;
    }
    
    if(!no_freeze){
        const float damping_mult = 0.5f;
        float damping = min(1.0f,ragdoll_static_time*damping_mult);
        this_mo.rigged_object().SetRagdollDamping(damping);
        if(damping >= 1.0f){
            frozen = true;
        }
    } else {
        this_mo.rigged_object().SetRagdollDamping(0.0f);
    }

    /*if(!this_mo.controlled){
        Print("Ragdoll static time: "+ragdoll_static_time+"\n");
    }*/
}

void SetActiveRagdollFallPose() {
    const float danger_radius = 4.0f;
    vec3 danger_vec;
    col.GetSlidingSphereCollision(this_mo.position, danger_radius * 0.25f); // Create sliding sphere at ragdoll center to detect nearby surfaces
    danger_vec = this_mo.position - sphere_col.adjusted_position;
    danger_vec += normalize(danger_vec) * danger_radius * 0.75f;
    if(sphere_col.NumContacts() == 0){
        col.GetSlidingSphereCollision(this_mo.position, danger_radius * 0.5f); // Create sliding sphere at ragdoll center to detect nearby surfaces
        danger_vec = this_mo.position - sphere_col.adjusted_position;
        danger_vec += normalize(danger_vec) * danger_radius * 0.5f;
    }
    if(sphere_col.NumContacts() == 0){
        col.GetSlidingSphereCollision(this_mo.position, danger_radius); // Create sliding sphere at ragdoll center to detect nearby surfaces
        danger_vec = this_mo.position - sphere_col.adjusted_position;
    }

    float ragdoll_strength = length(this_mo.rigged_object().GetAvgVelocity())*0.1f;
    ragdoll_strength = min(0.8f, ragdoll_strength);
    ragdoll_strength = max(0.0f, ragdoll_strength - ragdoll_limp_stun);
    if(knocked_out != _awake){
        // Strength fades the longer character is unconscious
        ragdoll_strength *= max(0.0f, 1.0f-(the_time - knocked_out_time));
    }
    this_mo.rigged_object().SetRagdollStrength(ragdoll_strength);

    float penetration = length(danger_vec);
    float penetration_ratio = penetration / danger_radius;
    float protect_amount = min(1.0f,max(0.0f,penetration_ratio*4.0f-2.0));
    protect_amount = mix(1.0f, protect_amount, ragdoll_strength / 0.8f);
    this_mo.rigged_object().anim_client().SetLayerOpacity(ragdoll_layer_fetal, protect_amount); // How much to try to curl up into a ball
    /*if(this_mo.controlled){
        Print("Protect amount: "+protect_amount+"\n");
    }*/

    mat4 torso_transform = this_mo.rigged_object().GetAvgIKChainTransform("torso");
    vec3 torso_vec = torso_transform.GetColumn(1);
    vec3 hazard_dir;
    if(penetration != 0.0f){
        hazard_dir = danger_vec / penetration;
    }
    float front_protect_amount = max(0.0f,dot(torso_vec, hazard_dir) * protect_amount);
    this_mo.rigged_object().anim_client().SetLayerOpacity(ragdoll_layer_catchfallfront, front_protect_amount); // How much to put arms out front to catch fall

}

void SetActiveRagdollInjuredPose(){
    const float time_until_death = 12.0f;
    float speed = length(this_mo.rigged_object().GetAvgVelocity());
    float ragdoll_strength = min(1.0f,max(0.2f,2.0f-speed*0.3f));
    ragdoll_strength *= (time_until_death - ragdoll_time)*0.1f;
    ragdoll_strength = min(0.9f, ragdoll_strength);
    ragdoll_strength = max(0.0f, ragdoll_strength - ragdoll_limp_stun);
    this_mo.rigged_object().SetRagdollStrength(ragdoll_strength);

    injured_mouth_open = mix(injured_mouth_open, 
                             sin(time*4.0f)*0.5f+sin(time*6.3f)*0.5f, 
                             ragdoll_strength);
    
    if(ragdoll_time > time_until_death){
        ragdoll_type = _RGDL_LIMP;
        no_freeze = false;
        ragdoll_static_time = 0.0f;
        this_mo.rigged_object().EnableSleep();
        this_mo.rigged_object().SetRagdollStrength(0.0f);
    }
}

void HandleRagdollRecovery(const Timestep &in ts) {
    recovery_time -= ts.step();
    roll_recovery_time -= ts.step();
    if(recovery_time <= 0.0f && length_squared(this_mo.rigged_object().GetAvgVelocity())<_auto_wake_vel_threshold){
        bool can_roll = CanRoll();
        if(can_roll){
            WakeUp(_wake_stand);
        } else {
            WakeUp(_wake_fall);
        }
    } else {
        if(WantsToRollFromRagdoll() && roll_recovery_time <= 0.0f){
            bool can_roll = CanRoll();
            if(!can_roll){
                WakeUp(_wake_flip);
            } else {
                WakeUp(_wake_roll);
            }
        }
        return;
    }
}


void SetRagdollType(int type) {
    if(ragdoll_type == type){
        //Print("*Setting ragdoll type to "+type+" but skipping\n");
        return;
    }    
    if(ragdoll_layer_fetal != -1){
        this_mo.rigged_object().anim_client().RemoveLayer(ragdoll_layer_fetal, 4.0f);       
    }
    if(ragdoll_layer_catchfallfront != -1){
        this_mo.rigged_object().anim_client().RemoveLayer(ragdoll_layer_catchfallfront, 4.0f);       
    }
    //Print("Setting ragdoll type to "+type+"\n");
    ragdoll_type = type;
    switch(ragdoll_type){
        case _RGDL_LIMP:
            no_freeze = false;
            this_mo.rigged_object().EnableSleep();
            this_mo.rigged_object().SetRagdollStrength(0.0);
            this_mo.SetAnimation("Data/Animations/r_idle.anm",4.0f,_ANM_FROM_START);
            break;
        case _RGDL_FALL:
            no_freeze = false;
            this_mo.rigged_object().EnableSleep();
            this_mo.rigged_object().SetRagdollStrength(1.0);
            this_mo.SetAnimation("Data/Animations/r_flail.anm",4.0f,_ANM_FROM_START);
            ragdoll_layer_catchfallfront = 
                this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_catchfallfront.anm",4.0f,0);
            ragdoll_layer_fetal = 
                this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_fetal.anm",4.0f,0);
            break;
        case _RGDL_INJURED:
            no_freeze = true;
            this_mo.rigged_object().DisableSleep();
            this_mo.rigged_object().SetRagdollStrength(1.0);
            this_mo.SetAnimation("Data/Animations/r_writhe.anm",4.0f,_ANM_FROM_START);
            //this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_grabface.anm",4.0f,_ANM_FROM_START);
            injured_mouth_open = 0.0f;
            break;
        case _RGDL_ANIMATION:
            no_freeze = true;
            this_mo.rigged_object().DisableSleep();
            this_mo.rigged_object().SetRagdollStrength(1.0);
            this_mo.SetAnimation("Data/Animations/r_idle.anm",4.0f,_ANM_FROM_START);
            this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_stomachcut.anm",4.0f,_ANM_FROM_START);
            break;
    }
}

void Ragdoll(int type){
    //Print("Ragdoll type " + type+"\n");
    UnTether();
    this_mo.rigged_object().SetRagdollDamping(0.0f);
    HandleAIEvent(_ragdolled);
    const float _ragdoll_recovery_time = 1.0f;
    recovery_time = _ragdoll_recovery_time;
    roll_recovery_time = 0.2f;
    ragdoll_time = 0.0f;
    
    if(state == _ragdoll_state){
        return;
    }
    ledge_info.on_ledge = false;
    this_mo.Ragdoll();
    SetState(_ragdoll_state);
    ragdoll_layer_catchfallfront = -1;
    ragdoll_layer_fetal = -1;
    ragdoll_static_time = 0.0f;
    ragdoll_time = 0.0f;
    ragdoll_limp_stun = 0.0f;
    frozen = false;
    ragdoll_type = _RGDL_NO_TYPE;
    SetRagdollType(type);
}

void GoLimp() {
    Ragdoll(_RGDL_FALL);
}

void SwitchToBlockedAnim() {
    this_mo.SwapAnimation(attack_getter.GetBlockedAnimPath());
    this_mo.rigged_object().anim_client().SetAnimationCallback("void EndAttack()");
    if(attack_getter.GetSwapStance() != attack_getter.GetSwapStanceBlocked()){
        mirrored_stance = !mirrored_stance;
    }
}

// WasBlocked() is executed if this character's attack was blocked by a different character
void WasBlocked() {
    SwitchToBlockedAnim();
}


void LayerRemoved(int id) {
    //Print("Removed layer: "+id+"\n");
    if(id == knife_layer_id){
        //Print("That was the active knife slash layer\n");
        knife_layer_id = -1;
    }
    if(id == throw_knife_layer_id){
        //Print("That was the active knife slash layer\n");
        throw_knife_layer_id = -1;
    }
    if(id == sheathe_layer_id){
        sheathe_layer_id = -1;
    }
}

// Handles what happens if a character was hit.  Includes blocking enemies' attacks, hit reactions, taking damage, going ragdoll and applying forces to ragdoll.
// Type is a string that identifies the action and thus the reaction, dir is the vector from the attacker to the defender, and pos is the impact position.
int WasHit(string type, string attack_path, vec3 dir, vec3 pos, int attacker_id, float attack_damage_mult, float attack_knockback_mult) {
    if(attack_path == ""){
        return _invalid;
    }
    attack_getter2.Load(attack_path);

    if(knife_layer_id != -1){
        this_mo.rigged_object().anim_client().RemoveLayer(knife_layer_id, 4.0f);       
    }
    if(throw_knife_layer_id != -1){
        this_mo.rigged_object().anim_client().RemoveLayer(throw_knife_layer_id, 4.0f);       
    }

    if(type == "grabbed"){
        return WasGrabbed(dir, pos, attacker_id);
    } else if(type == "attackblocked"){
        return BlockedAttack(dir, pos, attacker_id);
    } else if(type == "blockprepare"){
        return PrepareToBlock(dir, pos, attacker_id);
    } else if(type == "attackimpact"){
        return HitByAttack(dir, pos, attacker_id, attack_damage_mult, attack_knockback_mult);
    } else {
        return _invalid;
    }
}

void PrintVec3(vec3 vec){
    Print("("+vec.x + ", " + vec.y + ", " + vec.z + ")");
}

int WasGrabbed(const vec3&in dir, const vec3&in pos, int attacker_id){
    if(state == _ragdoll_state){
        return _miss;
    }
    if(tether_id != attacker_id){
        UnTether();
    }
    MovementObject@ attacker = ReadCharacterID(attacker_id);
    vec3 offset(attacker.position.x - this_mo.position.x,
                0.0f,
                attacker.position.z - this_mo.position.z);
    float dir_rotation = atan2(dir.z, dir.x);
    vec3 facing = this_mo.GetFacing();
    float cur_rotation = atan2(facing.z, facing.x);
    float rot_offset = cur_rotation - dir_rotation;
    this_mo.velocity.x = attacker.velocity.x;
    this_mo.velocity.z = attacker.velocity.z;
    int8 flags = _ANM_MOBILE | _ANM_FROM_START;
    mirrored_stance = false;
    if(attack_getter2.GetMirrored() == 0){
        flags = flags | _ANM_MIRRORED;
        mirrored_stance = true;
    }
    this_mo.SetAnimation(attack_getter2.GetThrownAnimPath(),5.0f,flags);
    this_mo.rigged_object().anim_client().AddAnimationOffset(offset);
    this_mo.rigged_object().anim_client().AddAnimationRotOffset(rot_offset);
    this_mo.rigged_object().anim_client().SetAnimationCallback("void EndHitReaction()");
    HandleAIEvent(_thrown);
    SetState(_hit_reaction_state);
    hit_reaction_anim_set = true;
    hit_reaction_thrown = true;
    flip_info.EndFlip();
    if(tethered == _TETHERED_REARCHOKED){
        HandleAIEvent(_choking);
    }
    return _hit;
}

void HandleWeaponWeaponCollision(int other_held_weapon){
    if(other_held_weapon == -1 || weapon_slots[primary_weapon_slot] == -1){
        return;
    }   
       
    ItemObject@ item_obj_a = ReadItemID(weapon_slots[primary_weapon_slot]);
    ItemObject@ item_obj_b = ReadItemID(other_held_weapon);
    if(item_obj_a.GetNumLines() == 0 ||
       item_obj_b.GetNumLines() == 0)
    {
        return;
    }
    vec3 a_start, a_end;
    vec3 b_start, b_end;
    mat4 trans_a = item_obj_a.GetPhysicsTransform();
    mat4 trans_b = item_obj_b.GetPhysicsTransform();
    vec3 col_point;
    float dist, closest_dist = 0.0f;
    vec3 a_point, b_point;
    int closest_line_a = -1;
    int closest_line_b;

    int num_lines_a = item_obj_a.GetNumLines();
    int num_lines_b = item_obj_b.GetNumLines();
    for(int i=0; i<num_lines_a; ++i){
        a_start = trans_a * item_obj_a.GetLineStart(i);
        a_end = trans_a * item_obj_a.GetLineEnd(i);
        for(int j=0; j<num_lines_b; ++j){
            b_start = trans_b * item_obj_b.GetLineStart(j);
            b_end = trans_b * item_obj_b.GetLineEnd(j);

            vec3 mu = LineLineIntersect(a_start, a_end, b_start, b_end);
            mu.x = min(1.0,max(0.0,mu.x));
            mu.y = min(1.0,max(0.0,mu.y));
            a_point = a_start + (a_end-a_start)*mu.x;
            b_point = b_start + (b_end-b_start)*mu.y;
            dist = distance_squared(a_point, b_point);
            if(closest_line_a == -1 || dist < closest_dist){
                closest_line_a = i;
                closest_line_b = j;
                closest_dist = dist;
                col_point = (a_point + b_point) * 0.5f;
            }
        }        
    }
    

    string mat_a, mat_b;
    mat_a = item_obj_a.GetLineMaterial(closest_line_a);
    mat_b = item_obj_b.GetLineMaterial(closest_line_b);

    string sound;
    if(mat_a == "metal" && mat_b == "metal"){
        sound = "Data/Sounds/weapon_foley/impact/weapon_metal_hit_metal_strong.xml";
        MakeMetalSparks(col_point);
    } else if(mat_a == "wood" && mat_b == "wood"){
        sound = "Data/Sounds/weapon_foley/impact/weapon_staff_hit_staff_strong.xml";
        MakeParticle("Data/Particles/impactfast.xml",col_point,vec3(0.0f));
        MakeParticle("Data/Particles/impactslow.xml",col_point,vec3(0.0f));
        int num_sparks = rand()%5;
        for(int i=0; i<num_sparks; ++i){
            MakeParticle("Data/Particles/woodspeck.xml",col_point,vec3(RangedRandomFloat(-5.0f,5.0f),
                                                                       RangedRandomFloat(-5.0f,5.0f),
                                                                       RangedRandomFloat(-5.0f,5.0f)));
        }   
    } else {
        sound = "Data/Sounds/weapon_foley/impact/weapon_staff_hit_metal_strong.xml";
        MakeParticle("Data/Particles/impactfast.xml",col_point,vec3(0.0f));
        MakeParticle("Data/Particles/impactslow.xml",col_point,vec3(0.0f));
        int num_sparks = rand()%10;
        for(int i=0; i<num_sparks; ++i){
            MakeParticle("Data/Particles/woodspeck.xml",col_point,vec3(RangedRandomFloat(-5.0f,5.0f),
                                                                       RangedRandomFloat(-5.0f,5.0f),
                                                                       RangedRandomFloat(-5.0f,5.0f)));
        }   
    }

    int sound_priority;
    if(this_mo.controlled){
        sound_priority = _sound_priority_very_high;  
    } else {
        sound_priority = _sound_priority_high;  
    }
    PlaySoundGroup(sound, col_point, sound_priority);  
}

void HandleWeaponCollision(int other_id){                   
    if(other_id == -1){
        return;
    }
    MovementObject@ char = ReadCharacterID(other_id);
    int other_held_weapon = GetCharPrimaryWeapon(char);
    HandleWeaponWeaponCollision(other_held_weapon);
}

int BlockedAttack(const vec3&in dir, const vec3&in pos, int attacker_id){
    string sound;
    if(attack_getter2.GetFleshUnblockable() == 0){
        level.SendMessage("active_blocked "+this_mo.getID()+" "+attacker_id);
        sound = "Data/Sounds/hit/hit_block.xml";
        MakeParticle("Data/Particles/impactfast.xml",pos,vec3(0.0f));
        MakeParticle("Data/Particles/impactslow.xml",pos,vec3(0.0f));

        MovementObject@ char = ReadCharacterID(attacker_id);
        int sound_priority;
        if(this_mo.controlled || char.controlled){
            sound_priority = _sound_priority_very_high;  
        } else {
            sound_priority = _sound_priority_high;  
        } 
        PlaySoundGroup(sound, pos, sound_priority);
    } else {
        HandleWeaponCollision(attacker_id);
    }
    //TimedSlowMotion(0.1f,0.3f, 0.05f);
    if(this_mo.controlled){
        camera.AddShake(0.5f);
    }

    this_mo.velocity += GetAdjustedAttackDir(dir) * 2.0f;
    tilt = GetAdjustedAttackDir(dir) * 20.0f;

    return _block_impact;
}

int IsDodging(){
    return (state == _hit_reaction_state && hit_reaction_dodge)?1:0;
}

int PrepareToBlock(const vec3&in dir, const vec3&in pos, int attacker_id){
    if(active_dodging){
        if(HandleDodge(dodge_dir, attacker_id)){
            return _miss;
        }
    }

    // active_blocking = true;
    if(!on_ground || flip_info.IsFlipping() || !active_blocking || 
        attack_getter2.GetUnblockable() != 0 || 
        (attack_getter2.GetFleshUnblockable() != 0 && 
        (weapon_slots[primary_weapon_slot] == -1 || ReadItemID(weapon_slots[primary_weapon_slot]).GetLabel() == "knife")))
    {
        return _miss;
    }

    if(active_block_flinch_layer != -1){
        this_mo.rigged_object().anim_client().RemoveLayer(active_block_flinch_layer, 100.0f);
        active_block_flinch_layer = -1;
    }

    if(state != _ragdoll_state && state != _ground_state){
        reaction_getter.Load(attack_getter2.GetReactionPath());
        SetState(_hit_reaction_state);
        hit_reaction_event = "blockprepare";
        active_block_anim = true;

        vec3 flat_dir(dir.x, 0.0f, dir.z);
        flat_dir = normalize(flat_dir) * -1;
        if(length_squared(flat_dir)>0.0f){
            this_mo.SetRotationFromFacing(flat_dir);
        }
    } else if(knocked_out == _awake) {
        WakeUp(_wake_block_stand);
        vec3 impact_dir = attack_getter2.GetImpactDir();
        vec3 right;
        right.x = -dir.z;
        right.z = dir.x;
        vec3 impact_dir_adjusted = impact_dir.x * right +
                                   impact_dir.z * dir;
        impact_dir_adjusted.y = 0.0f;
        this_mo.SetRotationFromFacing(impact_dir_adjusted);
    }

    HandleAIEvent(_activeblocked);
    return _going_to_block;
}

void AddBloodToStabWeapon(int attacker_id) {
    MovementObject@ attacker = ReadCharacterID(attacker_id);
    vec3 char_pos = attacker.position;
    int attacker_held_weapon = GetCharPrimaryWeapon(attacker);
    if(attacker_held_weapon != -1){
        ItemObject@ item_obj = ReadItemID(attacker_held_weapon);
        mat4 trans = item_obj.GetPhysicsTransform();
        int num_lines = item_obj.GetNumLines();
        vec3 dist_point;
        bool found_dist_point = false;
        vec3 start, end;
        float dist, far_dist = 0.0f;
        for(int i=0; i<num_lines; ++i){
            start = trans * item_obj.GetLineStart(i);
            end = trans * item_obj.GetLineEnd(i);
            dist = distance_squared(start, char_pos);
            if(!found_dist_point || dist > far_dist){
                found_dist_point = true;
                dist_point = start;
                far_dist = dist;
            }
            dist = distance_squared(end, char_pos);
            if(dist > far_dist){
                dist_point = end;
                far_dist = dist;
            }
        }
        vec3 weap_dir = normalize(end-start);
        vec3 side = normalize(cross(weap_dir, vec3(RangedRandomFloat(-1.0f,1.0f),
                                                   RangedRandomFloat(-1.0f,1.0f),
                                                   RangedRandomFloat(-1.0f,1.0f))));
        item_obj.AddBloodDecal(dist_point, normalize(side + weap_dir*2.0f), 0.5f);
    }
}

void AddBloodToCutPlaneWeapon(int attacker_id, vec3 dir) {
    MovementObject@ attacker = ReadCharacterID(attacker_id);
    int attacker_held_weapon = GetCharPrimaryWeapon(attacker);
    if(attacker_held_weapon != -1){
        ItemObject@ item_obj = ReadItemID(attacker_held_weapon);
        mat4 trans = item_obj.GetPhysicsTransform();
        mat4 torso_transform = this_mo.rigged_object().GetAvgIKChainTransform("head");
        vec3 char_pos = torso_transform * vec3(0.0f);
        vec3 point;
        vec3 col_point;
        float closest_dist = 0.0f;
        float closest_line = -1;
        vec3 start, end;
        float dist;
        int num_lines = item_obj.GetNumLines();
        for(int i=0; i<num_lines; ++i){
            if(item_obj.GetLineMaterial(i) != "metal"){
                continue;
            }
            start = trans * item_obj.GetLineStart(i);
            end = trans * item_obj.GetLineEnd(i);
            vec3 mu = LineLineIntersect(start, end, this_mo.position, char_pos);
            mu.x = min(1.0,max(0.0,mu.x));
            mu.y = min(1.0,max(0.0,mu.y));
            point = start + (end-start)*mu.x;
            dist = distance_squared(point, char_pos);
            //DebugDrawLine(start, end, vec3(1.0f), _persistent);
            if(closest_line == -1 || dist < closest_dist){
                closest_line = i;
                closest_dist = dist;
                col_point = point;
            }
        }
        vec3 weap_dir = normalize(end-start);
        dir = normalize(dir - dot(dir, weap_dir) * weap_dir);
        //DebugDrawLine(this_mo.position, char_pos, vec3(0.0f,0.0f,1.0f), _persistent);
        //DebugDrawWireSphere(col_point, 0.1f, vec3(1.0f,0.0f,0.0f), _persistent);
        item_obj.AddBloodDecal(col_point, dir, 0.5f);
    }
}

void TakeSharpDamage(float sharp_damage, vec3 pos, int attacker_id, bool allow_heavy_cut) {
    this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_painflinch.anm",8.0f,0);
    TakeBloodDamage(sharp_damage);
    if(attack_getter2.HasCutPlane()){
        vec3 cut_plane_local = attack_getter2.GetCutPlane();
        int cut_plane_type = attack_getter2.GetCutPlaneType();
        if(!allow_heavy_cut){
            cut_plane_type = 0;
        }
        if(attack_getter2.GetMirrored() == 1){
            cut_plane_local.x *= -1.0f;
        }
        vec3 facing = ReadCharacterID(attacker_id).GetFacing();
        vec3 facing_right = vec3(-facing.z, facing.y, facing.x);
        vec3 up(0.0f,1.0f,0.0f);
        vec3 cut_plane_world = facing * cut_plane_local.z +
            facing_right * cut_plane_local.x +
            up * cut_plane_local.y;

        vec3 avg_pos = this_mo.rigged_object().GetAvgPosition();
        float height_rel = avg_pos.y - (ReadCharacterID(attacker_id).position.y+0.45f);

        quaternion rotate(vec4(facing_right.x, facing_right.y, facing_right.z, height_rel*0.5f));
        cut_plane_world = Mult(rotate, cut_plane_world);
        facing = Mult(rotate, facing);
        up = Mult(rotate, up);
        this_mo.rigged_object().CutPlane(cut_plane_world, pos, facing, cut_plane_type, 0);
        const bool _draw_cut_plane = false;
        vec3 cut_plane_z = normalize(cross(up, cut_plane_world));
        vec3 cut_plane_x = normalize(cross(cut_plane_world, cut_plane_z));
        if(_draw_cut_plane){
            for(int i=-10; i<=10; ++i){
                DebugDrawLine(pos-cut_plane_z*0.5f+cut_plane_x*(i*0.1f)+facing*0.5, pos+cut_plane_z*0.5f+cut_plane_x*(i*0.1f)+facing*0.5, vec3(1.0f,1.0f,1.0f), _fade);
                DebugDrawLine(pos-cut_plane_x*0.5f+cut_plane_z*(i*0.1f)+facing*0.5, pos+cut_plane_x*0.5f+cut_plane_z*(i*0.1f)+facing*0.5, vec3(1.0f,1.0f,1.0f), _fade);
            }
        }
        AddBloodToCutPlaneWeapon(attacker_id, cut_plane_x*0.8f+cut_plane_world*0.2f);
    }
    if(attack_getter2.HasStabDir()){
        int attack_weapon_id = GetCharPrimaryWeapon(ReadCharacterID(attacker_id));
        if(attack_weapon_id != -1){
            int stab_type = attack_getter2.GetStabDirType();
            ItemObject@ item_obj = ReadItemID(attack_weapon_id);
            mat4 trans = item_obj.GetPhysicsTransform();
            mat4 trans_rotate = trans;
            trans_rotate.SetColumn(3, vec3(0.0f));
            vec3 stab_pos = trans * vec3(0.0f,0.0f,0.0f);
            //vec3 stab_dir = trans_rotate * attack_getter2.GetStabDir();
            int num_lines = item_obj.GetNumLines();
            if(num_lines > 0){
                vec3 start = trans * item_obj.GetLineStart(num_lines-1);
                vec3 end = trans * item_obj.GetLineEnd(num_lines-1);
                vec3 stab_dir = normalize(end-start);
                stab_pos -= stab_dir * 5.0f;
                const bool _draw_cut_line = false;
                if(_draw_cut_line){
                    DebugDrawLine(stab_pos,
                        stab_pos + stab_dir*10.0f,
                        vec3(1.0f),
                        _fade);
                }
                this_mo.rigged_object().Stab(stab_pos, stab_dir, stab_type, 0);
                AddBloodToStabWeapon(attacker_id);
            }
        }
    }
}

void MakeMetalSparks(vec3 pos){
    int num_sparks = rand()%20;
    for(int i=0; i<num_sparks; ++i){
        MakeParticle("Data/Particles/metalspark.xml",pos,vec3(RangedRandomFloat(-5.0f,5.0f),
                                                         RangedRandomFloat(-5.0f,5.0f),
                                                         RangedRandomFloat(-5.0f,5.0f)));
        
        MakeParticle("Data/Particles/metalflash.xml",pos,vec3(RangedRandomFloat(-5.0f,5.0f),
                                                         RangedRandomFloat(-5.0f,5.0f),
                                                         RangedRandomFloat(-5.0f,5.0f)));
    }   
}

int HitByAttack(const vec3&in dir, const vec3&in pos, int attacker_id, float attack_damage_mult, float attack_knockback_mult) {
    int old_knocked_out = knocked_out;
    // If active dodging or crouching under high attack, then attack misses
    if((state == _hit_reaction_state && hit_reaction_dodge) ||
       (attack_getter2.GetHeight() == _high && duck_amount >= 0.5f))
    {
        level.SendMessage("dodged "+this_mo.getID()+" "+attacker_id);
        return _miss;
    }
    attacked_by_id = attacker_id;
    if(this_mo.controlled){
        camera.AddShake(1.0f); // Shake camera if player is hit
    }
    if(tether_id != attacker_id){
        UnTether(); // Disconnect any tethering
    }
    if(attack_getter2.GetSpecial() == "legcannon"){
        block_health = 0.0f; // Legcannon bypasses passive block
    }
     
    // Check if player has a weapon that can block (anything but knife)
    bool has_blocking_weapon = false;
    int primary_weapon_id = weapon_slots[primary_weapon_slot];
    if(primary_weapon_id != -1){
        ItemObject@ weap = ReadItemID(primary_weapon_id);
        if(weap.GetLabel() != "knife"){
            has_blocking_weapon = true;
        }
    }
    
    // Check if attacker has a weapon that can be blocked (anything but knife)
    MovementObject@ char = ReadCharacterID(attacker_id);
    bool blockable_weapon_attack = false;
    int enemy_primary_weapon_id = GetCharPrimaryWeapon(char);
    if(enemy_primary_weapon_id != -1){
        ItemObject@ weap = ReadItemID(enemy_primary_weapon_id);
        if(weap.GetLabel() != "knife"){
            blockable_weapon_attack = true;
        }
    }
    
    // Apply damage to passive block health 
    float block_damage = attack_getter2.GetBlockDamage() * p_damage_multiplier * attack_damage_mult;
    block_health -= block_damage;
    if(state == _attack_state && blockable_weapon_attack && has_blocking_weapon){
        block_health -= block_damage * 0.5f; // Extra block damage if attacking when hit
    }

    block_health = max(0.0f, block_health);
    if(this_mo.controlled){
        AchievementEventFloat("player_block_damage", block_damage);
    }

    float sharp_damage = attack_getter2.GetSharpDamage();

    // Check if passive block is possible
    bool can_passive_block = true;
    bool can_animate_passive_block = true;
    bool can_gameplay_passive_block = true;
    if(flip_info.IsFlipping() || !on_ground || block_health <= 0.0f || blood_health <= 0.0f || state == _ragdoll_state){
       can_animate_passive_block = false;
    }
    if((startled && !this_mo.controlled) || 
       (state == _attack_state && (!blockable_weapon_attack || !has_blocking_weapon)) ||
       dot(dir, this_mo.GetFacing()) > 0.0f ||
       (sharp_damage > 0.0f && (!blockable_weapon_attack || !has_blocking_weapon)))
    {
       can_gameplay_passive_block = false;
    }
    if(!can_animate_passive_block || !can_gameplay_passive_block){
        can_passive_block = false;    
    }

    if(sharp_damage == 0.0f){
        MakeParticle("Data/Particles/impactfast.xml",pos,vec3(0.0f));
        MakeParticle("Data/Particles/impactslow.xml",pos,vec3(0.0f));
    }

    bool knocked_over = false;
    
    if(!can_passive_block){
        if(enemy_primary_weapon_id != -1){
            ItemObject@ weap = ReadItemID(enemy_primary_weapon_id);
            if(weap.GetLabel() == "spear"){
                if(can_animate_passive_block){
                    HandlePassiveBlockImpact(dir, pos);
                }
            }
        }
        if(sharp_damage > 0.0f){     
            level.SendMessage("cut "+this_mo.getID()+" "+attacker_id);   
            TakeSharpDamage(sharp_damage * attack_damage_mult, pos, attacker_id, true);
        }
		if(sharp_damage == 0.0f || knocked_out != _awake || block_health <= 0){
            float force = attack_getter2.GetForce()*(1.0f-max(0.0f,temp_health*0.5f)) * attack_knockback_mult;
            float damage = attack_getter2.GetDamage() * attack_damage_mult;
            if(enemy_primary_weapon_id != -1){
                ItemObject@ weap = ReadItemID(enemy_primary_weapon_id);
                int num_lines = weap.GetNumLines();
                mat4 trans = weap.GetPhysicsTransform();
                if(num_lines > 0){
                    vec3 start = trans * weap.GetLineStart(0);
                    vec3 end = trans * weap.GetLineEnd(num_lines-1);
                    HandleRagdollImpactLine(dir, pos, damage, force, normalize(end-start));
                } else {
                    HandleRagdollImpact(dir, pos, damage, force);
                }
            } else {
                HandleRagdollImpact(dir, pos, damage, force);
            }
            knocked_over = true;
            if(!this_mo.controlled && old_knocked_out == _awake){
                this_mo.PlaySoundGroupVoice("hit",0.0f);
            }
            if(sharp_damage > 0.0f && sharp_damage < 0.5f){
                ragdoll_limp_stun = 0.0f;
            }
        }
    } else {
        HandlePassiveBlockImpact(dir, pos);
        if(!this_mo.controlled && old_knocked_out == _awake){
            this_mo.PlaySoundGroupVoice("block_hit",0.0f);
        }
    }
    
    int sound_priority;
    if(this_mo.controlled || char.controlled){
        sound_priority = _sound_priority_very_high;  
    } else {
        sound_priority = _sound_priority_high;  
    } 
    if(sharp_damage <= 0.0f){
        if(knocked_over){
            level.SendMessage("knocked_over "+this_mo.getID()+" "+attacker_id);
            if(knocked_out == _dead && old_knocked_out != _dead){
                string sound = "Data/Sounds/hit/hit_hard.xml";
                PlaySoundGroup(sound, pos, sound_priority);
            } else {
                string sound = "Data/Sounds/hit/hit_medium.xml";
                PlaySoundGroup(sound, pos, sound_priority);
            }
        } else {
            level.SendMessage("passive_blocked "+this_mo.getID()+" "+attacker_id);
            string sound = "Data/Sounds/hit/hit_normal.xml";
            PlaySoundGroup(sound, pos, sound_priority);        
        }
        AISound(pos, LOUD_SOUND_AI);
    } else {
        string sound;
        if(weapon_slots[primary_weapon_slot] != -1 && can_passive_block){
            level.SendMessage("passive_blocked "+this_mo.getID()+" "+attacker_id);
            HandleWeaponCollision(attacker_id);
            if(rand()%2 == 0){
                sound = "Data/Sounds/weapon_foley/cut/flesh_hit.xml";
                PlaySoundGroup(sound, pos, sound_priority);  
                level.SendMessage("cut "+this_mo.getID()+" "+attacker_id);   
                TakeSharpDamage(0.3f, pos, attacker_id, false);
		        if(knocked_out != _awake){
                    GoLimp();
                }
            }
        } else {
            sound = "Data/Sounds/weapon_foley/cut/flesh_hit.xml";
            PlaySoundGroup(sound, pos, sound_priority);  
        }
        AISound(pos, QUIET_SOUND_AI);
        if(RangedRandomFloat(0.0f,1.0f) < drop_weapon_probability){
            HandleWeaponCollision(attacker_id);
            int item_id = DropWeapon();
            if(item_id != -1){
                ItemObject@ item_obj = ReadItemID(item_id);
                vec3 impulse = GetAdjustedAttackDir(dir) * 5.0f;
                item_obj.SetLinearVelocity(impulse);
                float rotation_amount = 20.0f;
                item_obj.SetAngularVelocity(vec3(RangedRandomFloat(-1.0f,1.0f),RangedRandomFloat(-1.0f,1.0f),RangedRandomFloat(-1.0f,1.0f)) * rotation_amount);
            }
        }
    }
    active_dodge_recharge = 0.0f;
    
    return _hit;
}

void PossibleHeadBleed(float damage){
    for(int i=0; i<3; ++i){
        if(RangedRandomFloat(0.0f,1.1f) < damage){
            this_mo.rigged_object().CreateBloodDrip("head", 0, vec3(RangedRandomFloat(-1.0f,1.0f),RangedRandomFloat(-0.2f,0.2f),0.0f));
        }
    }
}

void HandleRagdollImpactImpulse(const vec3&in impulse, const vec3&in pos, float damage){
    GoLimp();
    ragdoll_limp_stun = 0.9f;
    this_mo.rigged_object().ApplyForceToRagdoll(impulse, pos);
    block_health = 0.0f;
    PossibleHeadBleed(damage);
    TakeDamage(damage);
    if(startled && knocked_out == _awake){
        PossibleHeadBleed(damage);
        TakeDamage(damage);
    }
    temp_health = max(0.0f, temp_health);
}

void HandleRagdollImpactImpulseLine(const vec3&in impulse, const vec3&in pos, float damage, const vec3 &in line_dir){
    GoLimp();
    ragdoll_limp_stun = 0.9f;
    this_mo.rigged_object().ApplyForceLineToRagdoll(impulse, pos, line_dir);
    block_health = 0.0f;
    PossibleHeadBleed(damage);
    TakeDamage(damage);
    if(startled && knocked_out == _awake){
        PossibleHeadBleed(damage);
        TakeDamage(damage);
    }
    temp_health = max(0.0f, temp_health);
}

vec3 GetAdjustedAttackDir(const vec3&in dir) {
    vec3 impact_dir = attack_getter2.GetImpactDir();
    vec3 right;
    right.x = -dir.z;
    right.z = dir.x;
    right.y = dir.y;
    vec3 impact_dir_adjusted = impact_dir.x * right +
                               impact_dir.z * dir;
    impact_dir_adjusted.y += impact_dir.y;
    return impact_dir_adjusted;
}

void HandleRagdollImpact(const vec3&in dir, const vec3&in pos, float damage, float force){
    HandleRagdollImpactImpulse(GetAdjustedAttackDir(dir) * force, pos, damage);
}

void HandleRagdollImpactLine(const vec3&in dir, const vec3&in pos, float damage, float force, const vec3 &in line_dir){
    HandleRagdollImpactImpulseLine(GetAdjustedAttackDir(dir) * force, pos, damage, line_dir);
}

void HandlePassiveBlockImpact(const vec3&in dir, const vec3&in pos){    
    string reaction_path = attack_getter2.GetReactionPath();
    
    int weapon_id = weapon_slots[primary_weapon_slot];
    string weap_label = "";
    if(weapon_id != -1){
        ItemObject@ io = ReadItemID(weapon_id);
        weap_label = io.GetLabel();
    }
    reaction_getter.Load(reaction_path);
    SetState(_hit_reaction_state);

    hit_reaction_event = "attackimpact";

    vec3 flat_dir(dir.x, 0.0f, dir.z);
    flat_dir = normalize(flat_dir) * -1;
    if(length_squared(flat_dir)>0.0f){
        this_mo.SetRotationFromFacing(flat_dir);
    }
}

bool HandleDodge(const vec3&in dir, int attacker_id){

    vec3 face_dir = ReadCharacterID(attacker_id).position - this_mo.position;
    face_dir.y = 0.0;
    face_dir = normalize(face_dir);
    if(dot(face_dir, dir) > 0.85f){
        return false;
    }

    vec3 right_face_dir = vec3(face_dir.z, 0.0f, -face_dir.x);
    vec3 right_dir = vec3(dir.z, 0.0f, -dir.x);

    string anim_path;
    if(attack_getter2.GetHeight() == _high){
        anim_path = "Data/Animations/r_dodgebackhigh.anm";
    } else if(attack_getter2.GetHeight() == _medium){
        anim_path = "Data/Animations/r_dodgebackmid.anm";
    } else if(attack_getter2.GetHeight() == _low){
        anim_path = "Data/Animations/r_dodgebacklow.anm";
    }        
    this_mo.SetRotationFromFacing(dir * -1.0f);

    SetState(_hit_reaction_state);
    hit_reaction_anim_set = true;
    hit_reaction_dodge = true;

    int8 flags = _ANM_MOBILE | _ANM_FROM_START;
    if(mirrored_stance){
        flags = flags | _ANM_MIRRORED;
    }
    this_mo.SetAnimation(anim_path,10.0f,flags);
    this_mo.rigged_object().anim_client().SetAnimationCallback("void EndHitReaction()");
    attacked_by_id = attacker_id;
    return true;
}

void EndExecution() {
    executing = false;
}

void EndAttack() {
    this_mo.rigged_object().anim_client().SetAnimationCallback("");
    if(state != _attack_state){
        return;
    }
    SetState(_movement_state);
    if(!on_ground){
        flip_info.StartLegCannonFlip(this_mo.GetFacing()*-1.0f, leg_cannon_flip);
    }
}

void EndHitReaction() {
    if(state != _hit_reaction_state){
        return;
    }
    SetState(_movement_state);
}

void AchievementEvent(string event_str){
    level.SendMessage("achievement_event "+event_str);
}

void AchievementEventFloat(string event_str, float val){
    level.SendMessage("achievement_event_float "+event_str + " " + val);
}

void SetKnockedOut(int val) {
    if(val != _awake && knocked_out == _awake){
        knocked_out_time = the_time;
    }
    knocked_out = val;
    if(!this_mo.controlled){
        if(val == _dead || blood_health <= 0.0f ){
            AchievementEvent("enemy_died");
        }
    }
}

void ReceiveMessage(string msg){
    TokenIterator token_iter;
    token_iter.Init();
    if(!token_iter.FindNextToken(msg)){
        return;
    }
    string token = token_iter.GetToken(msg);
    if(token == "restore_health"){
        RecoverHealth();
    } else if(token == "start_talking"){
        test_talking = true;
    } else if(token == "stop_talking"){
        test_talking = false;
    } else if(token == "set_dialogue_control"){ // params: bool enabled
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        if(token == "true"){
            dialogue_control = true;
            this_mo.velocity = vec3(0.0f, 0.0f, 0.0f);            
            dialogue_torso_control = 0.0f;
            dialogue_head_control = 0.0f;
            test_talking = false;
            this_mo.rigged_object().anim_client().Reset();
            dialogue_anim = "Data/Animations/r_actionidle.anm";
        } else if(token == "false"){
            dialogue_control = false;
        }
    } else if(token == "set_head_target"){ // params: vec3 pos, float control
        // Get params
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        dialogue_head_target.x = atof(token);
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        dialogue_head_target.y = atof(token);
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        dialogue_head_target.z = atof(token);
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        dialogue_head_control = atof(token);
    } else if(token == "set_animation"){ // params: string path   
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        dialogue_anim = token;
    } else if(token == "set_eye_dir"){ 
        // Get params
        vec3 pos;        
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        pos.x = atof(token);
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        pos.y = atof(token);
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        pos.z = atof(token);
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        blink_mult = atof(token);

        dialogue_eye_dir = pos;
    } else if(token == "set_rotation"){ // params: float rotation
        // Get params     
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        float rotation = atof(token);
        vec3 new_facing = Mult(quaternion(vec4(0,1,0,rotation*3.1415f/180.0f)), vec3(1,0,0));
        this_mo.SetRotationFromFacing(new_facing);
    } else if(token == "set_dialogue_position"){ // params: float rotation
        // Get params     
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        dialogue_position.x = atof(token);
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        dialogue_position.y = atof(token);
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        dialogue_position.z = atof(token);
    } else if(token == "set_torso_target"){ // params: vec3 pos, float control
        // Get params
        vec3 pos;        
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        pos.x = atof(token);
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        pos.y = atof(token);
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        pos.z = atof(token);
        token_iter.FindNextToken(msg);
        token = token_iter.GetToken(msg);
        float control = atof(token);
        dialogue_torso_target = pos;
        dialogue_torso_control = control;
    } else {
        MindReceiveMessage(msg); // Pass message to mind if it doesn't match body messages
    }
}

void TakeDamage(float how_much){
    if(this_mo.controlled){
        AchievementEventFloat("player_damage", how_much);
    }
    HandleAIEvent(_damaged);
    const float _permananent_damage_mult = 0.4f;
    how_much *= p_damage_multiplier;
    temp_health -= how_much;
    permanent_health -= how_much * _permananent_damage_mult;
    if(permanent_health <= 0.0f && knocked_out != _dead){
        level.SendMessage("character_died "+this_mo.getID());
        SetKnockedOut(_dead);
        this_mo.StopVoice();
    }
    if(temp_health <= 0.0f && knocked_out == _awake){
        level.SendMessage("character_knocked_out "+this_mo.getID());
        SetKnockedOut(_unconscious);
        --lives;
        if(lives > 0){
            RecoverHealth();
            recovery_time = 3.0f;
            roll_recovery_time = 3.0f;
        } else {
            if(this_mo.controlled){
                TimedSlowMotion(0.1f,0.7f, 0.05f);
            }
            if(!this_mo.controlled && tethered == _TETHERED_FREE){
                this_mo.PlaySoundGroupVoice("death",0.4f);
            }
            //SetRagdollType(_RGDL_INJURED);
        }
    }
}

void TakeBloodDamage(float how_much){
    if(this_mo.controlled){
        AchievementEventFloat("player_blood_loss", how_much);
    }
    HandleAIEvent(_damaged);
    how_much *= p_damage_multiplier;
    blood_health -= how_much;
    if(permanent_health > blood_health){
        permanent_health -= how_much * 0.5f;
    }
    temp_health = min(permanent_health, temp_health);
    if(blood_health <= 0.0f && knocked_out == _awake){
        level.SendMessage("character_died "+this_mo.getID());
        SetKnockedOut(_unconscious);
    }
}

void TakeDelayedBloodDamage(float how_much){
    how_much *= p_damage_multiplier;
    blood_damage += how_much;
}

// Animation events are created by the animation files themselves. For example, when the run animation is played, it calls HandleAnimationEvent( "leftrunstep", left_foot_pos ) when the left foot hits the ground.
void HandleAnimationEvent(string event, vec3 world_pos){
    HandleAnimationMiscEvent(event, world_pos);
    HandleAnimationMaterialEvent(event, world_pos);
    HandleAnimationCombatEvent(event, world_pos);
    /*if(this_mo.controlled){
        DebugText("event"+(event_counter--), "Event: "+event, 3.0f);
    }*/
    //DebugDrawText(world_pos, event, _persistent);
}

void PlayItemGrabSound(ItemObject@ item_obj, float gain){
    vec3 pos = item_obj.GetPhysicsPosition();
    string sound_modifier = item_obj.GetSoundModifier();
    string sound;
    if(sound_modifier == "soft"){
        sound = "Data/Sounds/weapon_foley/impact/soft_bag_on_soft.xml";
    } else {
        sound = "Data/Sounds/weapon_foley/grab/weapon_grap_metal_leather_glove.xml";
    }
    PlaySoundGroup(sound, pos,gain);
}

void AttachWeapon(int which){
    if(weapon_slots[primary_weapon_slot] != -1 && weapon_slots[secondary_weapon_slot] != -1){
        Print("Can't attach weapon, already holding one!");
        return;
    }
    PlayItemGrabSound(ReadItemID(which), 0.5f);
    if(weapon_slots[primary_weapon_slot] == -1){
        bool mirror = primary_weapon_slot != _held_right;
        this_mo.AttachItemToSlot(which, _at_grip, mirror);
        HandleEditorAttachment(which, _at_grip, mirror);
    } else {
        bool mirror = secondary_weapon_slot != _held_right;
        this_mo.AttachItemToSlot(which, _at_grip, mirror);
        HandleEditorAttachment(which, _at_grip, mirror);
    }
}

void HandleEditorAttachment(int which, int attachment_type, bool mirror){
    Print("Handling editor attachment\n");
    ItemObject@ item_obj = ReadItemID(which);
    int weap_slot = -1;
    if(attachment_type == _at_grip){
        if(mirror){
            weap_slot = _held_left;
        } else {
            weap_slot = _held_right;
        } 
    } else if(attachment_type == _at_sheathe){
        if(mirror){
            weap_slot = _sheathed_right;
        } else {
            weap_slot = _sheathed_left;
        }         
    }
    Print("Requested attach item "+which+" to slot "+weap_slot+"\n");
    if(weap_slot == -1){
        Print("No such slot\n");
        return;
    }    
    if(weapon_slots[weap_slot] != -1){
        Print("Slot already has item "+weapon_slots[weap_slot]+"\n");
        bool new_goes_in_old = DoesItemFitInItem(which, weapon_slots[weap_slot]);
        bool old_goes_in_new = DoesItemFitInItem(weapon_slots[weap_slot], which);
        if(new_goes_in_old){
            Print("Item "+which+" could fit in item "+weapon_slots[weap_slot]+"\n");
            weapon_slots[weap_slot+2] = weapon_slots[weap_slot];
            weapon_slots[weap_slot] = which;
        } else if(old_goes_in_new) {
            Print("Item "+weapon_slots[weap_slot]+" could fit in item "+which+"\n");
            weapon_slots[weap_slot+2] = weapon_slots[which];
        } else {
            Print("Neither item can fit in the other\n");
        }
        return;
    }    
    weapon_slots[weap_slot] = which;
    
    if(weap_slot == _held_left || weap_slot == _held_right){
        UpdateItemFistGrip();
        UpdatePrimaryWeapon();
    }
}

void GrabWeaponFromBody(int stuck_id, int weapon_id, const vec3 &in pos) {{
    MovementObject@ char = ReadCharacterID(stuck_id);
    char.rigged_object().UnStickItem(weapon_id);
    if(stuck_id != this_mo.getID())
        char.Execute("RagdollRefresh(1);");
        char.rigged_object().ApplyForceToRagdoll(vec3(0.0f,1000.0f,0.0f), pos);
    }
    if(GetBloodLevel() != 0){
        MakeParticle("Data/Particles/bloodcloud.xml",pos,vec3(0.0f,1.0f,0.0f), GetBloodTint());
    }
    string sound = "Data/Sounds/weapon_foley/pickup/knife_remove.xml";
    PlaySoundGroup(sound, pos, 0.5f);
}

void Sheathe(int src, int dst){
    if(weapon_slots[src] != -1 && weapon_slots[dst+2] == -1){
        ItemObject@ item_obj = ReadItemID(weapon_slots[src]);
        vec3 pos = item_obj.GetPhysicsPosition();
        string sound = "Data/Sounds/weapon_foley/impact/weapon_drop_light_dirt.xml";
        PlaySoundGroup(sound, pos,0.5f);

        bool dst_right = (dst == _sheathed_right);
        this_mo.rigged_object().SheatheItem(weapon_slots[src], dst_right);
        weapon_slots[dst+2] = weapon_slots[dst];
        weapon_slots[dst] = weapon_slots[src];
        weapon_slots[src] = -1;
        UpdateItemFistGrip();
        UpdatePrimaryWeapon();
    }
}

void UnSheathe(int dst, int src){    
    if(weapon_slots[src] != -1 && weapon_slots[dst] == -1){
        ItemObject@ item_obj = ReadItemID(weapon_slots[src]);
        vec3 pos = item_obj.GetPhysicsPosition();
        string sound = "Data/Sounds/weapon_foley/grab/weapon_grap_metal_leather_glove.xml";
        PlaySoundGroup(sound, pos,0.5f);

        bool dst_right = (dst == _held_right);
        this_mo.rigged_object().UnSheatheItem(weapon_slots[src], dst_right);
        weapon_slots[dst] = weapon_slots[src];
        weapon_slots[src] = weapon_slots[src+2];
        weapon_slots[src+2] = -1;
        UpdateItemFistGrip();
        UpdatePrimaryWeapon();
    }
}

void HandleAnimationMiscEvent(const string&in event, const vec3&in world_pos) {
    if(event == "grabitem" && (weapon_slots[primary_weapon_slot] == -1 || weapon_slots[secondary_weapon_slot] == -1) && knocked_out == _awake && tethered == _TETHERED_FREE )
    {
        vec3 hand_pos;
        if(weapon_slots[_held_right] == -1 && (primary_weapon_slot == _held_right || weapon_slots[_held_left] != -1)){
            hand_pos = this_mo.rigged_object().GetIKTargetTransform("rightarm").GetTranslationPart();
        } else {
            hand_pos = this_mo.rigged_object().GetIKTargetTransform("leftarm").GetTranslationPart();
        }
        int nearest_weapon = GetNearestPickupableWeapon(hand_pos, 0.9f);
        if(nearest_weapon != -1){
            ItemObject@ item_obj = ReadItemID(nearest_weapon);
            vec3 pos = item_obj.GetPhysicsPosition();
            int stuck_id = item_obj.StuckInWhom();
            if(stuck_id != -1){
                GrabWeaponFromBody(stuck_id, item_obj.GetID(), pos);
            }
            AttachWeapon(item_obj.GetID());
            if(pickup_layer != -1){
                this_mo.rigged_object().anim_client().RemoveLayer(pickup_layer, 4.0f);
                pickup_layer = -1;
            } 
        }
        ++pickup_layer_attempts;
        if(pickup_layer_attempts > 4 && pickup_layer != -1){
            this_mo.rigged_object().anim_client().RemoveLayer(pickup_layer, 4.0f);
            pickup_layer = -1;
        }
    }
    if(event == "heldweaponswap" ){ 
        if(weapon_slots[_held_left] != -1){
            this_mo.DetachItem(weapon_slots[_held_left]);
        }
        if(weapon_slots[_held_right] != -1){
            this_mo.DetachItem(weapon_slots[_held_right]);
        }
        int temp = weapon_slots[_held_left];
        weapon_slots[_held_left] = weapon_slots[_held_right];
        weapon_slots[_held_right] = temp;
        if(weapon_slots[_held_left] != -1){
            this_mo.AttachItemToSlot(weapon_slots[_held_left], _at_grip, true);
        }
        if(weapon_slots[_held_right] != -1){
            this_mo.AttachItemToSlot(weapon_slots[_held_right], _at_grip, false);
        }
        string sound = "Data/Sounds/weapon_foley/impact/weapon_drop_light_dirt.xml";
        PlaySoundGroup(sound, world_pos,0.5f);
        UpdateItemFistGrip();
        UpdatePrimaryWeapon();
    }
    if(event == "sheatherighthandlefthip" ){ 
        Sheathe(_held_right, _sheathed_left);
    } else if(event == "sheathelefthandrighthip" ){
        Sheathe(_held_left, _sheathed_right);
    } else if(event == "sheathelefthandlefthip" ){
        Sheathe(_held_left, _sheathed_left);
    } else if(event == "sheatherighthandrighthip" ){
        Sheathe(_held_right, _sheathed_right);
    }
    if(event == "unsheatherighthandlefthip" ){ 
        UnSheathe(_held_right, _sheathed_left);
    } else if(event == "unsheathelefthandrighthip" ){
        UnSheathe(_held_left, _sheathed_right);
    } else if(event == "unsheathelefthandlefthi" ){
        UnSheathe(_held_left, _sheathed_left);
    } else if(event == "unsheatherighthandrighthi" ){
        UnSheathe(_held_right, _sheathed_right);
    }
}

void AISound(vec3 pos, float max_range){
    //DebugDrawWireSphere(pos, max_range, vec3(1.0f), _fade);
    string msg = "nearby_sound "+pos.x+" "+pos.y+" "+pos.z+" "+max_range+" "+this_mo.getID();
    array<int> nearby_characters;
    GetCharactersInSphere(pos, max_range, nearby_characters);
    int num_chars = nearby_characters.size();
    for(int i=0; i<num_chars; ++i){
        ReadCharacterID(nearby_characters[i]).ReceiveMessage(msg);
    }    
}

void HandleAnimationMaterialEvent(const string&in event, const vec3&in world_pos) {
    if(event == "leftstep" ||
       event == "leftwalkstep" ||
       event == "leftwallstep" ||
       event == "leftrunstep" ||
       event == "leftcrouchwalkstep")
    {
        //this_mo.rigged_object().MaterialDecalAtBone("step", "left_leg");
        this_mo.MaterialParticleAtBone("step","left_leg");
    }

    if(event == "rightstep" ||
       event == "rightwalkstep" ||
       event == "rightwallstep" ||
       event == "rightrunstep" ||
       event == "rightcrouchwalkstep")
    {
        //this_mo.rigged_object().MaterialDecalAtBone("step", "right_leg");
        this_mo.MaterialParticleAtBone("step","right_leg");
    }

    if(event == "leftwallstep" || event == "rightwallstep" ||
       event == "leftrunstep" || event == "rightrunstep")
    {
        if(character_getter.GetTag("species") == "cat"){
            this_mo.MaterialEvent("leftcrouchwalkstep", world_pos);
            AISound(world_pos, QUIET_SOUND_AI);
        } else {
            this_mo.MaterialEvent(event, world_pos);
            AISound(world_pos, LOUD_SOUND_AI);
        }
    } else if(event == "leftcrouchwalkstep" || event == "rightcrouchwalkstep" ||
              event == "leftwalkstep" || event == "rightwalkstep" ||
              event == "leftstep" || event == "rightstep")
    {
        if(character_getter.GetTag("species") == "cat"){
            this_mo.MaterialEvent(event, world_pos, 0.3f);
        } else {
            this_mo.MaterialEvent(event, world_pos);
            AISound(world_pos, QUIET_SOUND_AI);
        }
    } 
}

void HandleAnimationCombatEvent(const string&in event, const vec3&in world_pos) {
    if(event == "golimp"){
        if(this_mo.controlled){
            AchievementEvent("player_was_hit");
        }
        if(state == _hit_reaction_state && hit_reaction_thrown){
            level.SendMessage("character_thrown "+this_mo.getID() + " " + attacked_by_id);
        }
        //if(attack_getter2.IsThrow() == 1){
        //    TakeDamage(attack_getter2.GetDamage());
        //}
        GoLimp();
    }
    if(event == "throatcut"){
        if(tether_id != -1){
            MovementObject@ char = ReadCharacterID(tether_id);
            char.Execute("Execute(FINISHING_THROAT_CUT);"); 
            vec3 pos = char.rigged_object().GetIKChainPos("head",1); 
            for(int i=0; i<3; ++i){
                AddBloodToCutPlaneWeapon(this_mo.getID(), pos + vec3(RangedRandomFloat(-0.3f,0.3f),RangedRandomFloat(-0.3f,0.3f),RangedRandomFloat(-0.3f,0.3f)));
            }
        }
    }
    if(event == "rightweaponrelease"){
         ThrowWeapon();
    } else if(event == "leftweaponrelease"){
         ThrowWeapon();
    }

    bool attack_event = false;
    if(event == "attackblocked" ||
       event == "attackimpact" ||
       event == "blockprepare")
    {
        attack_event = true;
    }
    if(event == "attackblocked" && feinting){
        string sound = "Data/Sounds/weapon_foley/swoosh/weapon_whoos_big.xml";
        this_mo.PlaySoundGroupAttached(sound,this_mo.position);
        level.SendMessage("character_attack_feint "+this_mo.getID()+" "+target_id);
        return;
    }
    if(event == "blockprepare"){
        can_feint = false;
    }
    if(attack_event == true && target_id != -1){
        vec3 target_pos = ReadCharacterID(target_id).position;
        bool missed = true;
        if(event == "attackblocked" || distance(this_mo.position, target_pos) < (_attack_range + range_extender + 0.1f) * this_mo.rigged_object().GetCharScale()){
            vec3 facing = this_mo.GetFacing();
            vec3 facing_right = vec3(-facing.z, facing.y, facing.x);
            vec3 dir = normalize(target_pos - this_mo.position);
            int return_val = ReadCharacterID(target_id).WasHit(
                   event, attack_getter.GetPath(), dir, world_pos, this_mo.getID(), p_attack_damage_mult, p_attack_knockback_mult);
            if(return_val == _going_to_block){
                WasBlocked();
            }
            if((return_val == _hit || return_val == _block_impact) && this_mo.controlled){
                camera.AddShake(0.5f);
            }
            if(return_val != _miss){
                missed = false;
            }
            if(return_val != _miss && attack_getter.GetSpecial() == "legcannon"){
                this_mo.velocity += dir * -10.0f;
            }
            if(return_val == _block_impact){
                block_stunned = 0.5f;
                block_stunned_by_id = target_id;
            }
            if(event == "frontkick"){
                if(distance(this_mo.position, target_pos) < 1.0f){
                    MovementObject @char = ReadCharacterID(target_id);
                    char.position = this_mo.position + dir;
                }
            }
            /*if((return_val == _hit) && !this_mo.controlled){
                if(rand()%2==0){
                    string sound = "Data/Sounds/voice/torikamal/hit_taunt.xml";
                    this_mo.PlaySoundGroupVoice(sound,0.2f);
                }
            }*/
        }
        if(missed && (event == "attackblocked" || event == "attackimpact")){
            level.SendMessage("character_attack_missed "+this_mo.getID()+" "+target_id);
            MovementObject@ char = ReadCharacterID(target_id);
            int sound_priority;
            if(this_mo.controlled || char.controlled){
                sound_priority = _sound_priority_very_high;  
            } else {
                sound_priority = _sound_priority_high;  
            } 
            string sound = "Data/Sounds/whoosh/hit_whoosh.xml";
            PlaySoundGroup(sound, world_pos, sound_priority);
        }
    }
}

// remove Y component, the up component, from a vector. 
vec3 flatten(vec3 vec){
    return vec3(vec.x,0.0,vec.z);
}

vec3 WorldToGroundSpace(vec3 world_space_vec){
    vec3 right = normalize(cross(ground_normal,vec3(0,0,1)));
    vec3 front = normalize(cross(right,ground_normal));
    vec3 ground_space_vec = right * world_space_vec.x +
                            front * world_space_vec.z +
                            ground_normal * world_space_vec.y;
    if(!this_mo.controlled){
        vec3 flat = normalize(world_space_vec)*
            sqrt(ground_space_vec.x*ground_space_vec.x + 
                 ground_space_vec.z*ground_space_vec.z);
        ground_space_vec.x = flat.x;
        ground_space_vec.z = flat.z;
    }
    return ground_space_vec;
}

// WantsToDoSomething functions are called by the player or the AI in playercontrol.as or enemycontrol.as
// For the player, they return true when the appopriate control key is down.
void UpdateGroundMovementControls(const Timestep &in ts) {
    vec3 target_velocity = GetTargetVelocity(); // GetTargetVelocity() is defined in enemycontrol.as and playercontrol.as. Player target velocity depends on the camera and controls, AI's on player's position.
    if(length_squared(target_velocity)>0.0f){
        feet_moving = true;
    }

    // target_duck_amount is used in UpdateDuckAmount() 
    if(WantsToCrouch()){
        target_duck_amount = 1.0f;
        if(stance_move){
            target_duck_amount = mix(1.0f, 0.3f, min(1.0f,sqrt(this_mo.velocity.x*this_mo.velocity.x + this_mo.velocity.z*this_mo.velocity.z)/5.0f));
        }
    } else {
        target_duck_amount = 0.0f;
    }
    if(tethered == _TETHERED_DRAGBODY && drag_strength_mult < 0.7f){
        target_duck_amount = 1.0f;    
    }        
    if(knife_layer_id != -1){
        if(target_id != -1){
            vec3 avg_pos = ReadCharacterID(target_id).rigged_object().GetAvgPosition();
            float height_rel = avg_pos.y - (this_mo.position.y+0.45f);
            if(height_rel < 0.0f){
                target_duck_amount = max(target_duck_amount, min(1.0f, height_rel * -1.0f));
            }
        }
    }
    if(tethered == _TETHERED_FREE){
        if(WantsToRoll() && length_squared(target_velocity)>0.2f){
            // flip_info handles actions in the air, including jump flips
            if(!flip_info.IsFlipping()){
                flip_info.StartRoll(target_velocity);
                breath_speed += 1.0f;
            }
        }

        // If the characters has been touching the ground for longer than _jump_threshold_time and isn't already jumping, update variables 
        // Actual jump is activated after the if(pre_jump) clause below.
        if(WantsToJump() && on_ground_time > _jump_threshold_time && !pre_jump){
            int jump_arm_layer = this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_jump_arms.anm",2.0f,0);
            this_mo.rigged_object().anim_client().SetLayerOpacity(jump_arm_layer, 0.5f); 
            pre_jump = true;
            const float _pre_jump_delay = 0.04f; // the time between a jump being initiated and the jumper getting upwards velocity, time available for pre-jump animation
            pre_jump_time = _pre_jump_delay;
            duck_vel = 30.0f * (1.0f-duck_amount * 0.6f); // The character crouches down, getting ready for the jump
            vec3 target_jump_vel = jump_info.GetJumpVelocity(target_velocity);
            target_tilt = vec3(target_jump_vel.x, 0, target_jump_vel.z)*2.0f;
        }
        // Preparing for the jump
        if(pre_jump){
            if(pre_jump_time <= 0.0f && !flip_info.IsFlipping()){
                if(TargetedJump()){
                    jump_info.StartJump(GetTargetJumpVelocity(), true);
                    breath_speed += 2.0f;
                } else {
                    float speed_mult = min(1.0f, length(this_mo.velocity)/max_speed + 0.2f);
                    jump_info.StartJump(target_velocity * speed_mult, false);
                    breath_speed += 2.0f;
                }
                HandleAIEvent(_jumped);
                SetOnGround(false);
                pre_jump = false;
            } else {
                pre_jump_time -= ts.step();
            }
        }
    }
    
    vec3 flat_ground_normal = ground_normal;
    flat_ground_normal.y = 0.0f;
    float flat_ground_length = length(flat_ground_normal);
    flat_ground_normal = normalize(flat_ground_normal);
    if(flat_ground_length > 0.9f){
        if(this_mo.controlled && dot(target_velocity, flat_ground_normal) < 0.0f){
            target_velocity -= dot(target_velocity, flat_ground_normal) * flat_ground_normal;
        }
    }
    
    if(flat_ground_length > 0.6f){
        if(this_mo.controlled && dot(this_mo.velocity, flat_ground_normal)>-0.8f){
            target_velocity -= dot(target_velocity, flat_ground_normal) * flat_ground_normal;
            target_velocity += flat_ground_normal * flat_ground_length;
            feet_moving = true;
        }
        if(length(target_velocity)>1.0f){
            target_velocity = normalize(target_velocity);
        }
    }
    

    vec3 adjusted_vel = WorldToGroundSpace(target_velocity);

    // Adjust speed based on ground slope
    max_speed = run_speed;
    if(tethered != _TETHERED_FREE){
        max_speed *= 0.25f;   
        //if(tethered == _TETHERED_DRAGBODY){
            max_speed *= 0.5f;   
        //}
    }
    float curr_speed = length(this_mo.velocity);
    
    max_speed *= 1.0 - adjusted_vel.y;
    max_speed = max(curr_speed * 0.98f, max_speed);
    max_speed = min(max_speed, true_max_speed);

    float speed = _walk_accel * run_phase;
    if(character_getter.GetTag("species") == "cat"){
        speed = mix(speed,speed*_duck_speed_mult,duck_amount*0.5f);
    } else {
        speed = mix(speed,speed*_duck_speed_mult,duck_amount);
    }
    if(in_plant > 0.0f){
        speed *= mix(1.0f,mix(0.3f, 0.6f, duck_amount),in_plant);
    }
    
    this_mo.velocity += adjusted_vel * ts.step() * speed;
    
}

// Draws a sphere on the position of the bone's IK target. Useful for understanding what the IK targets do, or are supposed to do.
// Useful strings:  leftarm, rightarm, left_leg, right_leg
void DrawIKTarget(string str) {
    vec3 pos = this_mo.rigged_object().GetIKTargetPosition(str);
    DebugDrawWireSphere(pos,
                        0.1f,
                        vec3(1.0f),
                        _delete_on_draw);
}

// sets IK target and draws a debugging line between the old and new positions of the IK target.
void MoveIKTarget(string str, vec3 offset) {
    vec3 pos = this_mo.rigged_object().GetIKTargetPosition(str);
    DebugDrawLine(pos,
                  pos+offset,
                  vec3(1.0f),
                  _delete_on_draw);
    this_mo.rigged_object().SetIKTargetOffset(str, offset);

}

void ForceApplied(vec3 force) {
}

float GetTempHealth() {
    return temp_health;
}

vec3 GetDragOffsetWorld(){
    vec3 facing = this_mo.GetFacing();
    vec3 right_facing = vec3(-facing.z, 0.0f, facing.x);
    if(mirrored_stance){
        right_facing *= -1.0f;
    }
    vec3 drag_offset_world = this_mo.position + 
        facing * drag_offset.z + 
        right_facing * drag_offset.x +
        vec3(0.0f,1.0f,0.0f) * drag_offset.y;
    drag_offset_world.y += 0.1f - duck_amount * 0.2f;
    return drag_offset_world;
}

void SetTethered(int val){
    tethered = val;
    //Print("Setting tethered to "+TetheredStr(tethered)+"\n");
}

void SetTetherID(int val){
    tether_id = val;
}

bool IsLayerAttacking() {
    return last_knife_time <= time && last_knife_time >= time - 0.3f;
}

// Executed only when the  character is in _movement_state. Called by UpdateGroundControls() 
void UpdateGroundAttackControls(const Timestep &in ts) {
    if(IsLayerAttacking()){
        return;
    }
    //DebugDrawWireSphere(this_mo.position, _attack_range + range_extender, vec3(1.0f), _delete_on_update);
    const float range = (_attack_range + range_extender)*range_multiplier*this_mo.rigged_object().GetCharScale() - _leg_sphere_size;
    int attack_id = -1;
    int throw_id = -1;
    int sneak_throw_id = -1;
    if(WantsToAttack()){
        int closest_id = GetClosestCharacterID(range, _TC_ENEMY | _TC_CONSCIOUS);
        if(closest_id != -1){
            int danger_id = GetClosestCharacterID(range, _TC_ENEMY | _TC_CONSCIOUS | _TC_NON_RAGDOLL);
            if(danger_id == -1){
                attack_id = closest_id;
            } else {
                attack_id = danger_id;
            }
        }
        // If no conscious targets, check for unconscious
        if(attack_id == -1 && this_mo.controlled){
            closest_id = GetClosestCharacterID(range, _TC_ENEMY);
            if(closest_id != -1){
                attack_id = closest_id;
            }
        }
    }
    if(WantsToThrowEnemy()){
        throw_id = GetClosestCharacterID(range, _TC_ENEMY | _TC_CONSCIOUS | _TC_NON_RAGDOLL | _TC_THROWABLE);
        sneak_throw_id = GetClosestCharacterID(range, _TC_ENEMY | _TC_CONSCIOUS | _TC_NON_RAGDOLL | _TC_UNAWARE);
    }
    if(throw_id != -1){
        if(this_mo.controlled){
            AchievementEvent("player_counter_attacked");
        }
        SetState(_attack_state);
        breath_speed += 2.0f;
        attack_animation_set = false;
        attacking_with_throw = 1;
        can_feint = false;
        feinting = false;
        SetTargetID(throw_id);
    } else if(sneak_throw_id != -1 && 
        abs(this_mo.position.y - ReadCharacterID(sneak_throw_id).position.y) < 
        _max_tether_height_diff)
    {
        if(this_mo.controlled){
            AchievementEvent("player_sneak_attacked");
        }
        SetState(_attack_state);
        breath_speed += 2.0f;
        attack_animation_set = false;
        attacking_with_throw = 2;
        can_feint = false;
        feinting = false;
        SetTargetID(sneak_throw_id);
        SetTethered(_TETHERED_REARCHOKE);
        SetTetherID(target_id);
        MovementObject @char = ReadCharacterID(target_id);
        tether_rel = char.position - this_mo.position;
        tether_rel.y = 0.0f;
        tether_rel = normalize(tether_rel);
        char.Execute("SetTethered(" + _TETHERED_REARCHOKED + ");" +
                     "SetTetherID(" + this_mo.getID() + ");");
        
        char.MaterialEvent("choke_grab", char.position);
        //PlaySoundGroup("Data/Sounds/hit/grip.xml", this_mo.position);
    } else if(attack_id != -1){
        if(this_mo.controlled){
            AchievementEvent("player_attacked");
        }
        breath_speed += 2.0f;
        LoadAppropriateAttack(false);
        if(attack_getter.GetAsLayer() == 1){
            if(mirrored_stance && state == _movement_state){
                mirrored_stance = left_handed;
                ApplyIdle(4.0f, true);
            }
            int flags = 0;
            if(primary_weapon_slot == _held_left){
                flags = _ANM_MIRRORED;
            }
            if(target_id != -1){
                vec3 avg_pos = ReadCharacterID(target_id).rigged_object().GetAvgPosition();
                float height_rel = avg_pos.y - (this_mo.position.y+0.45f);
                this_mo.rigged_object().anim_client().SetBlendCoord("attack_height_coord",height_rel + RangedRandomFloat(0.0f,0.2f));
            }
            if(backslash){
                knife_layer_id = this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_knifebackslash.xml",7.0f,flags);
                attack_getter.Load("Data/Attacks/knifebackslash.xml");
                //Print("Back slash\n");
            } else {
                knife_layer_id = this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_knifeslash.xml",7.0f,flags);
                attack_getter.Load("Data/Attacks/knifeslash.xml");
                //Print("Front slash\n");
            }
            backslash = !backslash;
            last_knife_time = time;
            if(!this_mo.controlled){
                this_mo.PlaySoundGroupVoice("attack",0.0f);
            }
        } else {
            if(this_mo.controlled){
                AchievementEvent("player_attacked");
            }
            breath_speed += 2.0f;
            SetState(_attack_state);
            attack_animation_set = false;
        }
        attacking_with_throw = 0;
        can_feint = true;
        feinting = false;
        SetTargetID(attack_id);
    } 
}

void UpdateAirAttackControls() {
    int air_attack_id = -1;
    if(WantsToAttack()){
        int closest_id = GetClosestCharacterID(3.0f, _TC_ENEMY | _TC_CONSCIOUS);
        air_attack_id = closest_id;
    }
    if(air_attack_id == -1){
        return;
    }
    if(WantsToAttack() && !flip_info.IsFlipping() &&
        distance(this_mo.position + this_mo.velocity * 0.3f,
                 ReadCharacterID(air_attack_id).position + ReadCharacterID(air_attack_id).velocity * 0.3f) <= _attack_range + range_extender)
    {
        SetTargetID(air_attack_id);
        SetState(_attack_state);
        can_feint = false;
        feinting = false;
        attack_animation_set = false;
        attacking_with_throw = 0;
    }
}

// Executed only when the  character is in _movement_state.  Called by UpdateMovementControls() .
void UpdateGroundControls(const Timestep &in ts) {
    if(tethered == _TETHERED_FREE){
        UpdateGroundAttackControls(ts);
    } else if(tethered == _TETHERED_REARCHOKE && WantsToAttack() && !executing && weapon_slots[primary_weapon_slot] != -1) {
    	// Cut victim's throat
        uint8 flags = _ANM_FROM_START;
        if(mirrored_stance){
            flags = flags|_ANM_MIRRORED;   
        }
        this_mo.SetAnimation("Data/Animations/r_throatcutter.anm", 10.0f, flags);
        this_mo.rigged_object().anim_client().SetAnimationCallback("void EndExecution()");
        this_mo.rigged_object().anim_client().SetAnimatedItemID(0, weapon_slots[primary_weapon_slot]);
        executing = true;        
        vec3 pos = ReadItemID(weapon_slots[primary_weapon_slot]).GetPhysicsPosition();
        string sound = "Data/Sounds/weapon_foley/cut/flesh_hit.xml";
        PlaySoundGroup(sound, pos, _sound_priority_very_high);  
        MovementObject@ char = ReadCharacterID(tether_id);
        char.rigged_object().CutPlane(vec3(0.0f,1.0f,0.0f), pos, this_mo.GetFacing() * -1.0f, 0, 0);
        char.Execute("Execute(STARTING_THROAT_CUT);");
    }
    UpdateGroundMovementControls(ts);
}

// handles tilting caused by accelerating when moving on the ground.
void HandleAccelTilt(const Timestep &in ts) {
    if(on_ground){
        if(feet_moving && state == _movement_state){
            target_tilt = this_mo.velocity * 0.5f / this_mo.rigged_object().GetCharScale();
            accel_tilt = mix((this_mo.velocity - old_vel)*120.0f/ts.frames(), accel_tilt, pow(0.95f,ts.frames()));
        } else {
            target_tilt = vec3(0.0f);
            accel_tilt *= pow(0.8f,ts.frames());
        }
        target_tilt += accel_tilt / this_mo.rigged_object().GetCharScale();
        target_tilt.y = 0.0f;
        old_vel = this_mo.velocity;
    } else {
        accel_tilt = vec3(0.0f);
        old_vel = vec3(0.0f);
    }
}

void ApplyIdle(float speed, bool start){
    if(this_mo.rigged_object().anim_client().GetCurrAnim() == "Data/Animations/r_smallswordstancefront.xml"){
        mirrored_stance = !left_handed;
    }
    uint8 flags = 0;
    if(mirrored_stance){
        flags = flags|_ANM_MIRRORED;   
    }
    if(start){
        flags = flags | _ANM_FROM_START;
    }
    string AI_idle_anim_override = GetIdleOverride();
    if(AI_idle_anim_override != ""){
        this_mo.SetAnimAndCharAnim(AI_idle_anim_override, speed, flags,"idle");
    } else {
        if(blood_health < 1.0f){
            if(weapon_slots[primary_weapon_slot] == -1){
                if(blood_health < 0.5f && length_squared(this_mo.velocity) < 0.5f){
                    this_mo.SetAnimAndCharAnim("Data/Animations/r_woundedidle.xml", speed, flags,"idle");
                } else {
                    this_mo.SetAnimAndCharAnim("Data/Animations/r_halfwoundedidle.xml", speed, flags,"idle");
                }
            } else {
                if(blood_health < 0.5f){
                    this_mo.SetAnimAndCharAnim("Data/Animations/r_woundedarmed.xml", speed, flags,"idle");
                } else {
                    this_mo.SetAnimAndCharAnim("Data/Animations/r_halfwoundedarmed.xml", speed, flags,"idle");
                }
            }
        } else {
            if(idle_type == _combat){
                this_mo.SetCharAnimation("idle",speed,flags);
            } else {
                string path;
                if(idle_type == _active){
                    path = "Data/Animations/r_actionidle.xml";
                } else if(idle_type == _stand){
                    path = "Data/Animations/r_relaxidle.xml";
                }
                this_mo.SetAnimAndCharAnim(path, speed, flags,"idle");
            }
        }
    }
    /*if(this_mo.controlled){
        DebugText("a","Primary weapon: "+weapon_slots[primary_weapon_slot],0.5f);
    }*/
    this_mo.rigged_object().anim_client().SetAnimatedItemID(0, weapon_slots[primary_weapon_slot]);
}

// Executed only when the  character is in _movement_state.  Called from the update() function.
void UpdateMovementControls(const Timestep &in ts) {
    if(on_ground){ 
        if(!flip_info.HasControl()){
            UpdateGroundControls(ts);
        } 
        flip_info.UpdateRoll(ts);
    } else if(ledge_info.on_ledge){
        ledge_info.UpdateLedge(ts);
        flip_info.UpdateFlip(ts);
    } else {
        jump_info.UpdateAirControls(ts);
        UpdateAirAttackControls();
        if(jump_info.ClimbedUp()){
            SetOnGround(true);
            duck_amount = 1.0f;
            duck_vel = 2.0f;
            target_duck_amount = 1.0f;
            ApplyIdle(20.0f, true);
            HandleBumperCollision();
            HandleStandingCollision();
            this_mo.position = sphere_col.position;
            this_mo.velocity = GetTargetVelocity() * true_max_speed * 0.2f;
            feet_moving = false;
            this_mo.MaterialEvent("land_soft", this_mo.position);
        } else {
            flip_info.UpdateFlip(ts);
            // Update air tilt            
            target_tilt = vec3(this_mo.velocity.x, 0, this_mo.velocity.z) * 2.0f;
            vec3 flail_tilt(sin(time*5.0f)*10.0f,0.0f,cos(time*3.0f+0.75f)*10.0f);
            target_tilt += jump_info.GetFlailingAmount()*flail_tilt;
            if(abs(this_mo.velocity.y)<_tilt_transition_vel && !flip_info.HasFlipped()){
                target_tilt *= pow(abs(this_mo.velocity.y)/_tilt_transition_vel,0.5);
            }
            if(this_mo.velocity.y < 0.0f || flip_info.HasFlipped()){
                target_tilt *= -1.0f;
            }
        }
    }
}

// Used when the character starts or stops touching the ground. The timer affects how quickly a character can jump after landing, and other things. 
void SetOnGround(bool _on_ground){
    on_ground_time = 0.0f;
    air_time = 0.0f;
    on_ground = _on_ground;
}

float GetVisionDistance(const vec3&in target_pos){
    float direct_vision = dot(this_mo.GetFacing(), normalize(target_pos-this_mo.position));
    direct_vision = max(0.0f, direct_vision);
    return direct_vision * vision_threshold;
}

void GetMatchingCharactersInArray(array<int> &in characters, array<int> &out matching_characters, uint16 flags){
    int num = characters.size();

    for(int i=0; i<num; ++i){
        if(this_mo.getID() == characters[i]) {
            continue;
        }        
        if(flags & _TC_KNOWN != 0 && !situation.KnowsAbout(characters[i])) {
            continue;
        }
        MovementObject@ char = ReadCharacterID(characters[i]);
        if(flags & _TC_CONSCIOUS != 0 && char.GetIntVar("knocked_out") != _awake) {
            continue;
        }
        if(flags & _TC_UNCONSCIOUS != 0 && char.GetIntVar("knocked_out") == _awake) {
            continue;
        }        
        character_getter.Load(this_mo.char_path);
        if(flags & _TC_ENEMY != 0 && this_mo.OnSameTeam(char)) {
            continue;
        }
        if(flags & _TC_ALLY != 0 && !this_mo.OnSameTeam(char)) {
            continue;
        }        
        if(flags & _TC_IDLE != 0 && char.QueryIntFunction("int IsIdle()") == 0) {
            continue;
        }
        if(flags & _TC_THROWABLE != 0 && (char.GetFloatVar("block_stunned") == 0.0f || char.GetIntVar("block_stunned_by_id") != this_mo.getID())) {
            continue;
        }        
        if(flags & _TC_NON_RAGDOLL != 0 && char.GetIntVar("state") == _ragdoll_state) {
            continue;
        }        
        if(flags & _TC_RAGDOLL != 0 && char.GetIntVar("state") != _ragdoll_state) {
            continue;
        }        
        if(flags & _TC_UNAWARE != 0 && char.QueryIntFunction("int IsUnaware()")!=1) {
            continue;
        }
        matching_characters.push_back(characters[i]);
    }
}

int GetClosestCharacterInArray(vec3 pos, array<int> &in characters, float range){
    int num = characters.size();
    int closest_id = -1;
    float closest_dist = 0.0f;

    for(int i=0; i<num; ++i){
        int id = characters[i];
        MovementObject@ char = ReadCharacterID(id);        
        vec3 target_pos = char.position;
        float dist = distance_squared(pos, target_pos);
        if(range > 0.0f && dist > range * range){
            continue;
        }
        if(closest_id == -1 || dist < closest_dist) {
           closest_dist = dist;
           closest_id = id;
        }
    }
    return closest_id;
}

const string fov_path = "Data/Models/fov.obj";
const string head_string = "head";
array<int> nearby_characters;    
void GetVisibleCharacters(uint16 flags, array<int> &visible_characters){
    nearby_characters.resize(0);
    mat4 transform = this_mo.rigged_object().GetAvgIKChainTransform(head_string);
    mat4 transform_offset;
    transform_offset.SetRotationX(-70);
    transform.SetRotationPart(transform.GetRotationPart()*transform_offset);
    GetCharactersInHull(fov_path, transform, nearby_characters);
    //DebugDrawWireMesh("Data/Models/fov.obj", transform, vec4(1.0f), _delete_on_update);
    vec3 head_pos = this_mo.rigged_object().GetAvgIKChainPos(head_string);
    for(uint i=0; i<nearby_characters.size(); ++i){
        if(this_mo.getID() != nearby_characters[i] &&
           ReadCharacterID(nearby_characters[i]).VisibilityCheck(head_pos))
        {
            visible_characters.push_back(nearby_characters[i]);
        }
    }
}

int GetClosestCharacterID(float range, uint16 flags){
    array<int> nearby_characters;
    GetCharactersInSphere(this_mo.position, range + 1.0f, nearby_characters);
    array<int> matching_characters;
    GetMatchingCharactersInArray(nearby_characters, matching_characters, flags);
    return GetClosestCharacterInArray(this_mo.position, matching_characters, range + _leg_sphere_size);
}

// this is called when the character lands in a non-ragdoll mode
void Land(vec3 vel, const Timestep &in ts) {
    // this is true when the character initiated a flip during jump and isn't finished yet
    if(flip_info.ShouldRagdollOnLanding()){
        level.SendMessage("character_failed_flip "+this_mo.getID());
        GoLimp();
        return;
    }

    SetOnGround(true);
    
    float land_speed = 10.0f;//min(30.0f,max(10.0f, -vel.y));
    ApplyIdle(land_speed, true);

    if(dot(this_mo.velocity*-1.0f, ground_normal)>0.3f){
        float slide_amount = 1.0f - (dot(normalize(this_mo.velocity*-1.0f), normalize(ground_normal)));
        //Print("Slide amount: "+slide_amount+"\n");
        //Print("Slide vel: "+slide_amount*length(this_mo.velocity)+"\n");
        if(character_getter.GetTag("species") == "cat"){
            this_mo.MaterialEvent("land", this_mo.position - vec3(0.0f,_leg_sphere_size, 0.0f), 0.5f);
            AISound(this_mo.position, QUIET_SOUND_AI);
        } else {
            this_mo.MaterialEvent("land", this_mo.position - vec3(0.0f,_leg_sphere_size, 0.0f), 1.0f);
            AISound(this_mo.position, LOUD_SOUND_AI);
        }
        if(slide_amount > 0.0f){
            float slide_vel = slide_amount*length(this_mo.velocity);
            float vol = min(1.0f,slide_amount * slide_vel * 0.2f);
            if(character_getter.GetTag("species") == "cat"){
                vol *= 0.5f;
            }
            if(vol > 0.2f){
                this_mo.MaterialEvent("slide", this_mo.position - vec3(0.0f,_leg_sphere_size, 0.0f), vol);
            }
        }
        duck_amount = 1.0;
        target_duck_amount = 1.0;
        duck_vel = land_speed * 0.3f;
    } else {
        if(character_getter.GetTag("species") == "cat"){
            this_mo.MaterialEvent("land_soft", this_mo.position - vec3(0.0f,_leg_sphere_size, 0.0f), 0.5f);
        } else {
            this_mo.MaterialEvent("land_soft", this_mo.position - vec3(0.0f,_leg_sphere_size, 0.0f));
            AISound(this_mo.position, QUIET_SOUND_AI);
        }
    }

    if(WantsToCrouch()){
        duck_vel = max(6.0f,duck_vel);
    }

    feet_moving = false;

    flip_info.Land();
    old_slide_vel = this_mo.velocity;
    this_mo.velocity.y = max(this_mo.velocity.y, -10.0f);
}

void GetCollisionSphere(vec3 &out offset, vec3 &out scale, float &out size){
    if(on_ground){
        offset = vec3(0.0f,mix(0.3f,0.15f,duck_amount),0.0f);
        scale = vec3(1.0f,mix(1.4f,0.6f,duck_amount),1.0f);
        size = _bumper_size;
    } else {
        offset = vec3(0.0f,mix(0.2f,0.35f,flip_info.GetTuck()),0.0f);
        scale = vec3(1.0f,mix(1.25f,1.0f,flip_info.GetTuck()),1.0f);
        size = _leg_sphere_size;
    }
}

vec3 HandleBumperCollision(){
    vec3 offset;
    vec3 scale;
    float size;
    GetCollisionSphere(offset, scale, size);
    col.GetSlidingScaledSphereCollision(this_mo.position+offset, size, scale);
    if(_draw_collision_spheres){
        DebugDrawWireScaledSphere(this_mo.position+offset,size,scale,vec3(0.0f,1.0f,0.0f),_delete_on_update);
    }
    // the value of sphere_col.adjusted_position variable was set by the GetSlidingSphereCollision() called on the previous line.
    this_mo.position = sphere_col.adjusted_position-offset;
    return (sphere_col.adjusted_position - sphere_col.position);
}

vec3 HandlePiecewiseBumperCollision(vec3 old_pos){
    vec3 new_pos = this_mo.position; 
    vec3 old_new_pos = new_pos;
    old_pos.y += 0.3f;
    new_pos.y += 0.3f;
    vec3 offset;
    vec3 test_pos = mix(old_pos, new_pos, 0.25f);
    col.GetSlidingSphereCollision(test_pos, _bumper_size);
    offset = sphere_col.adjusted_position - sphere_col.position;
    new_pos += offset/0.25f;
    test_pos = mix(old_pos, new_pos, 0.5f);
    col.GetSlidingSphereCollision(test_pos, _bumper_size);
    offset = sphere_col.adjusted_position - sphere_col.position;
    new_pos += offset/0.5f;
    test_pos = mix(old_pos, new_pos, 0.75f);
    col.GetSlidingSphereCollision(test_pos, _bumper_size);
    offset = sphere_col.adjusted_position - sphere_col.position;
    new_pos += offset/0.75f;
    test_pos = mix(old_pos, new_pos, 1.0f);
    col.GetSlidingSphereCollision(test_pos, _bumper_size);
    offset = sphere_col.adjusted_position - sphere_col.position;
    new_pos += offset/1.0f;
    new_pos.y -= 0.3f;
    this_mo.position = new_pos;
    return new_pos - old_new_pos;
}

bool HandleStandingCollision() {
    vec3 upper_pos = this_mo.position+vec3(0,0.1f,0);
    vec3 lower_pos = this_mo.position+vec3(0,-0.2f,0);
    col.GetSweptSphereCollision(upper_pos,
                                 lower_pos,
                                 _leg_sphere_size);

    if(_draw_collision_spheres){
        DebugDrawWireSphere(upper_pos,_leg_sphere_size,vec3(0.0f,0.0f,1.0f),_delete_on_update);
        DebugDrawWireSphere(lower_pos,_leg_sphere_size,vec3(0.0f,0.0f,1.0f),_delete_on_update);
    }
    return (sphere_col.position == lower_pos);
}

void CheckForVelocityShock(float vert_vel) {
    float shock = vert_vel * -1.0f;
    //Print("Velocity shock: "+shock+"\n");
    if(shock > _shock_damage_threshold){
        TakeDamage((shock-_shock_damage_threshold)*_shock_damage_multiplier);
        if(knocked_out == _unconscious){
            Ragdoll(_RGDL_INJURED);
            string sound = "Data/Sounds/hit/hit_hard.xml";
            PlaySoundGroup(sound, this_mo.position);
        } else if(knocked_out == _dead){
            Ragdoll(_RGDL_LIMP);
            string sound = "Data/Sounds/hit/hit_hard.xml";
            PlaySoundGroup(sound, this_mo.position);
        } else {
            string sound = "Data/Sounds/hit/hit_medium_juicy.xml";
            PlaySoundGroup(sound, this_mo.position);
        }
    }
}

PredictPathOutput PredictPath(vec3 start, vec3 end){
    PredictPathOutput predict_path_output;
    predict_path_output.type = _ppt_none;

    vec3 raycast_point = NavRaycast(start, end);
    if(distance_squared(raycast_point, NavRaycast(start, end + normalize(end-start))) > 0.01f){
        return predict_path_output;
    }
    vec3 dir = end - start;
    dir.y = 0.0f;
    dir = normalize(dir);
    vec3 right = vec3(-dir.z, 0.0f, dir.x);
    
    vec3 point = raycast_point + vec3(0.0f,2.5f,0.0f);
    col.GetSlidingSphereCollision(point,2.0f);
    if(sphere_col.NumContacts() == 0){
        //DebugDrawWireSphere(point,2.0f,vec3(1.0f,0.0f,0.0f),_delete_on_update);
        col.GetSweptSphereCollision(point + dir * 4.0f, point + dir * 4.0f+ vec3(0.0f,-100.0f,0.0f), _leg_sphere_size);
        vec3 fall_point = sphere_col.position;
        //DebugDrawWireSphere(fall_point,_leg_sphere_size,vec3(1.0f,1.0f,1.0f),_delete_on_update);
        
        vec3 low = fall_point;
        vec3 high = fall_point;
        high.y = start.y;
        /*DebugDrawLine(start, high, vec3(1.0f), _fade);
        DebugDrawLine(low, high, vec3(1.0f), _fade);
        DebugDrawLine(low, low+right*0.1f, vec3(1.0f), _fade);
        DebugDrawLine(low, low-right*0.1f, vec3(1.0f), _fade);
        DebugDrawLine(high, high+right*0.1f, vec3(1.0f), _fade);
        DebugDrawLine(high, high-right*0.1f, vec3(1.0f), _fade);*/

        predict_path_output.type = _ppt_drop;
        predict_path_output.start_pos = high;
        predict_path_output.end_pos = low;
    } else {
        //DebugDrawWireSphere(point,2.0f,vec3(1.0f,1.0f,1.0f),_delete_on_update);
        vec3 sphere_offset = normalize(point - sphere_col.adjusted_position);
        vec3 intersect = sphere_col.adjusted_position + sphere_offset * 2.0f;
        sphere_offset.y = 0.0f;
        sphere_offset = normalize(sphere_offset);
        //DebugDrawWireSphere(intersect,1.0f,vec3(0.0f,1.0f,0.0f),_delete_on_update);
        vec3 ledge_height_check = intersect - sphere_offset*_leg_sphere_size;
        ledge_height_check.y = start.y;
        LedgeHeightInfo ledge_height_info = GetLedgeHeightInfo(ledge_height_check, sphere_offset);
        if(ledge_height_info.success){
            vec3 low = raycast_point;
            vec3 high = point;
            high.y = ledge_height_info.edge_height;
            vec3 sphere_offset_right(-sphere_offset.z, 0.0f, sphere_offset.x);
            /*DebugDrawLine(start, low, vec3(1.0f), _fade);
            DebugDrawLine(low, high, vec3(1.0f), _fade);
            DebugDrawLine(low, low+sphere_offset_right*0.1f, vec3(1.0f), _fade);
            DebugDrawLine(low, low-sphere_offset_right*0.1f, vec3(1.0f), _fade);
            DebugDrawLine(high, high+sphere_offset_right*0.1f+vec3(0.0f,-0.3f,0.0f), vec3(1.0f), _fade);
            DebugDrawLine(high, high-sphere_offset_right*0.1f+vec3(0.0f,-0.3f,0.0f), vec3(1.0f), _fade);*/
            predict_path_output.type = _ppt_climb;
            predict_path_output.start_pos = low;
            predict_path_output.end_pos = high;
            predict_path_output.normal = sphere_offset;
        }
    }
    return predict_path_output;
}

void HandleGroundCollisions(const Timestep &in ts) {
    // Check if character has room to stand up
    float old_duck_amount = duck_amount;
    if(!WantsToCrouch()){
        duck_amount = duck_amount - 0.1f;
    }
    vec3 test_bumper_collision_response(0.0f, -10.0f, 0.0f);
    while(test_bumper_collision_response.y < -0.8f && duck_amount != 1.0f){
        vec3 offset;
        vec3 scale;
        float size;
        GetCollisionSphere(offset, scale, size);
        offset.y += 0.1f;
        if(scale.y > 1.0f){
            offset.y += size*(scale.y - 1.0f);
            scale.y = 1.0f;
        }
        col.GetSlidingScaledSphereCollision(this_mo.position+offset, size, scale);
        test_bumper_collision_response = normalize(sphere_col.adjusted_position - sphere_col.position);
        if(test_bumper_collision_response.y < -0.8f){
            duck_amount += 0.01f;
            duck_amount = min(1.0f, duck_amount);
        }
    }
    if(duck_amount <= old_duck_amount){
        duck_amount = old_duck_amount;
    } else if(duck_amount > old_duck_amount){
        duck_vel = 0.0f;
    }
    
    vec3 bumper_collision_response = HandleBumperCollision();
    if(normalize(bumper_collision_response).y < -0.8f){
        for(int i=0; i<10; ++i){
            col.GetSlidingSphereCollision(this_mo.position, _leg_sphere_size);
            this_mo.position = sphere_col.adjusted_position;
            this_mo.velocity += (sphere_col.adjusted_position - sphere_col.position) / ts.step();
            this_mo.velocity += bumper_collision_response / ts.step();
            bumper_collision_response = HandleBumperCollision();
        }
    }
    /*if(!this_mo.controlled && length_squared(bumper_collision_response) > 0.0f){
        if(ledge_info.CheckLedges(true)){
            HandleAIEvent(_can_climb);
        }
    }*/
    this_mo.velocity += bumper_collision_response / ts.step(); // Push away from wall, and apply velocity change verlet style

    //if(sphere_col.NumContacts() != 0 && flip_info.ShouldRagdollIntoWall()){
    //    GoLimp();    
    //}

    if((/*sphere_col.NumContacts() != 0 ||*/                                // If standing on overly-sloped surface, start this_mo.controlled fall
        ground_normal.y < _ground_normal_y_threshold)                       
        && this_mo.velocity.y > 0.2f &&
        false)
    {
        SetOnGround(false);
        jump_info.StartFall();
        UnTether();
    }

    bool in_air = HandleStandingCollision();                                // Move vertically to stand on surface, or fall if there is no surface
    if(in_air){
        SetOnGround(false);
        jump_info.StartFall();
        UnTether();
    } else {
        this_mo.position = sphere_col.position;
        /*DebugDrawWireSphere(sphere_col.position,
        sphere_col.radius,
        vec3(1.0f,0.0f,0.0f),
        _delete_on_update);*/
        for(int i=0; i<sphere_col.NumContacts(); i++){
            const CollisionPoint contact = sphere_col.GetContact(i);
            float dist = distance(contact.position, this_mo.position);
            if(dist <= _leg_sphere_size + 0.01f){
                ground_normal = ground_normal * 0.9f +                      // Calculate ground_normal with moving average of contact point normals
                    contact.normal * 0.1f;
                ground_normal = normalize(ground_normal);
                /*DebugDrawLine(sphere_col.position,
                sphere_col.position-contact.normal,
                vec3(1.0f,0.0f,0.0f),
                _delete_on_update);*/
            }
        }/*
         DebugDrawLine(sphere_col.position,
         sphere_col.position-ground_normal,
         vec3(0.0f,1.0f,0.0f),
         _delete_on_update);
         */

        /*if(flip_info.ShouldRagdollIntoSteepGround() &&
        dot(this_mo.GetFacing(),ground_normal) < -0.6f){
        GoLimp();    
        }*/
    }
}

void HandleAirCollisions(const Timestep &in ts) {
    vec3 initial_vel = this_mo.velocity;
    vec3 offset = this_mo.position - last_col_pos; 
    this_mo.position = last_col_pos;
    bool landing = false;
    vec3 landing_normal;
    vec3 old_vel = this_mo.velocity;
    for(int i=0; i<ts.frames(); ++i){                                        // Divide movement into multiple pieces to help prevent surface penetration
        if(on_ground){
            break;
        }
        this_mo.position += offset/ts.frames();
        vec3 col_offset;
        vec3 col_scale;
        float size;
        GetCollisionSphere(col_offset, col_scale, size);
        col.GetSlidingScaledSphereCollision(this_mo.position+col_offset, _leg_sphere_size, col_scale);
        if(_draw_collision_spheres){
            DebugDrawWireScaledSphere(this_mo.position+col_offset, _leg_sphere_size, col_scale, vec3(0.0f,1.0f,0.0f), _delete_on_update);
        }
        this_mo.position = sphere_col.adjusted_position-col_offset;         // Collide like a sliding sphere with verlet-integrated velocity response
        vec3 adjustment = (this_mo.position - (sphere_col.position-col_offset));
        adjustment.y = min(0.0f,adjustment.y);
        this_mo.velocity += adjustment / (ts.step());
        offset += (sphere_col.adjusted_position - sphere_col.position) * ts.frames();
        vec3 closest_point;
        float closest_dist = -1.0f;
        for(int j=0; j<sphere_col.NumContacts(); j++){
            const CollisionPoint contact = sphere_col.GetContact(j);
            if(contact.normal.y < _ground_normal_y_threshold){              // If collision with a surface that can't be walked on, check for wallrun
                float dist = distance_squared(contact.position, this_mo.position);
                if(closest_dist == -1.0f || dist < closest_dist){
                    closest_dist = dist;
                    closest_point = contact.position;
                }
            }
        }    
        if(closest_dist != -1.0f){
            jump_info.HitWall(normalize(closest_point-this_mo.position));
        }
        for(int j=0; j<sphere_col.NumContacts(); j++){
            if(landing){
                break;
            }
            const CollisionPoint contact = sphere_col.GetContact(j);
            if(contact.normal.y > _ground_normal_y_threshold ||
               (this_mo.velocity.y < 0.0f && contact.normal.y > 0.2f))
            {                                                               // If collision with a surface that can be walked on, then land
                if(air_time > 0.1f){
                    landing = true;
                    landing_normal = contact.normal;
                }
            }
        }
    }
    if(landing){
        CheckForVelocityShock(old_vel.y);                                   // Check landing damage from high-speed falls
        if(knocked_out == _awake){                                          // If still conscious, land properly
            ground_normal = landing_normal;
            Land(initial_vel, ts);
            if(state != _ragdoll_state){
                SetState(_movement_state);
            }
        }
    }
    if(this_mo.velocity.y < 0.0f && old_vel.y >= 0.0f){
        this_mo.velocity.y = 0.0f;
    }
}


void HandleLedgeCollisions(const Timestep &in ts) {
    if(ledge_info.ghost_movement){
        return;
    }
    vec3 col_offset(0.0f,0.8f,0.0f);
    vec3 col_scale(1.05f);
    col.GetSlidingScaledSphereCollision(this_mo.position+col_offset, _leg_sphere_size, col_scale);
    if(_draw_collision_spheres){
        DebugDrawWireScaledSphere(this_mo.position+col_offset, _leg_sphere_size, col_scale, vec3(0.0f,1.0f,0.0f), _delete_on_update);
    }
    this_mo.position = sphere_col.adjusted_position-col_offset;                 // Collide like a sliding sphere with verlet-integrated velocity response
    vec3 adjustment = (this_mo.position - (sphere_col.position-col_offset));
    //Print("Adjustment: "+adjustment.x+" "+adjustment.y+" "+adjustment.z+"\n");
    this_mo.velocity += adjustment / ts.step();
    vec3 closest_point;
    float closest_dist = -1.0f;
    for(int i=0; i<sphere_col.NumContacts(); i++){
        const CollisionPoint contact = sphere_col.GetContact(i);
        if(contact.normal.y < _ground_normal_y_threshold){                      // If collision with a surface that can't be walked on, check for wallrun
            float dist = distance_squared(contact.position, this_mo.position);
            if(closest_dist == -1.0f || dist < closest_dist){
                closest_dist = dist;
                closest_point = contact.position;
            }
        }
    }    
}

void HandleCollisions(const Timestep &in ts) {
    vec3 initial_vel = this_mo.velocity;
    if(_draw_collision_spheres){
        DebugDrawWireSphere(this_mo.position,
                            _leg_sphere_size,
                            vec3(1.0f,1.0f,1.0f),
                            _delete_on_update);
    }    
    if(on_ground){
        HandleGroundCollisions(ts);
    } else {
        if(ledge_info.on_ledge){
            HandleLedgeCollisions(ts);
        } else {
            HandleAirCollisions(ts);
        }
    }
    last_col_pos = this_mo.position;

    // Flatten velocity against previous velocity
    if(dot(initial_vel, this_mo.velocity) < 0.0f){                              // If velocity is in opposite direction from old velocity,
        vec3 initial_dir = normalize(initial_vel);                              // flatten it against plane with normal of old velocity
        float wrong_dist = -dot(initial_dir, this_mo.velocity);
        this_mo.velocity += initial_dir * wrong_dist;
    }

    // Collisions should not increase speed
    if(length_squared(initial_vel) < length_squared(this_mo.velocity)){         // If speed is greater than before collision, set it to the
        this_mo.velocity = normalize(this_mo.velocity)*length(initial_vel);     // old speed
    }
}


void UpdateDuckAmount(const Timestep &in ts) { // target_duck_amount is 1.0 when the character should crouch down, and 0.0 when it should stand straight.
    const float _duck_accel = 120.0f;
    const float _duck_vel_inertia = 0.89f;
    duck_vel += (target_duck_amount - duck_amount) * ts.step() * _duck_accel;
    duck_vel *= pow(_duck_vel_inertia,ts.frames());
    duck_amount += duck_vel * ts.step();
    //duck_amount = min(1.0,duck_amount);
}


void UpdateThreatAmount(const Timestep &in ts) { 
    target_threat_amount = (WantsToAttack() && state == _movement_state || state == _attack_state)?1.0f:0.0f;
    const float _threat_accel = (weapon_slots[primary_weapon_slot] != -1)?150.0f:300.0f;
    const float _threat_vel_inertia = 0.89f;
    threat_vel += (target_threat_amount - threat_amount) * ts.step() * _threat_accel;
    threat_vel *= pow(_threat_vel_inertia,ts.frames());
    threat_amount += threat_vel * ts.step();
}


void UpdateGroundAndAirTime(const Timestep &in ts) { // tells how long the character has been touching the ground, or been in the air
    if(on_ground){
        on_ground_time += ts.step();
    } else {
        air_time += ts.step();
    }
}

void UpdateAirWhooshSound() { // air whoosh sounds get louder at higher speed.
    float whoosh_amount;
    if(state != _ragdoll_state){
       whoosh_amount = length(this_mo.velocity)*0.05f;
    } else {
       whoosh_amount = length(this_mo.rigged_object().GetAvgVelocity())*0.05f;
    }
    if(state != _ragdoll_state){
        whoosh_amount += flip_info.WhooshAmount();
    }
    float whoosh_pitch = min(2.0f,whoosh_amount*0.5f + 0.5f);
    if(!on_ground){
        whoosh_amount *= 1.5f;
    }
    //Print("Whoosh amount: "+whoosh_amount+"\n");
    SetAirWhoosh(whoosh_amount*0.5f,whoosh_pitch);
}

int GetState() {
    return state;
}

bool IsAttackMirrored(){
    vec3 direction = GetAttackDirection();
    vec3 right_direction;
    right_direction.x = direction.z;
    right_direction.z = -direction.x;

    bool mirrored;
    if(!mirrored_stance){
        // GetTargetVelocitY() is defined in enemycontrol.as and playercontrol.as. Player target velocity depends on the camera and controls, AI's on player's position.
        mirrored = (dot(right_direction, GetTargetVelocity())>0.1f);
    } else {
        mirrored = (dot(right_direction, GetTargetVelocity())>-0.1f);
    }
    if(!this_mo.controlled){
        mirrored = rand()%2==0;
    }    
    return mirrored;
}

void CheckPossibleAttack(string &in attack_str) {
    attack_getter.Load(character_getter.GetAttackPath(attack_str));
    string anim_path = attack_getter.GetUnblockedAnimPath();
    float impact_time = GetAnimationEventTime(anim_path, "attackimpact");
    Print(attack_str + ": " + character_getter.GetAttackPath(attack_str) + "( " + impact_time + ")\n");
    //DebugText("impact_time", "Attack impact_time: "+impact_time, 1.0f);
}

void CheckPossibleAttacks() {
    CheckPossibleAttack("low");
    CheckPossibleAttack("moving_low");
    CheckPossibleAttack("stationary");
    CheckPossibleAttack("moving");
    CheckPossibleAttack("stationary_close");
    CheckPossibleAttack("moving_close");
}

bool LoadAppropriateAttack(bool mirrored) {
    bool orig_mirrored = mirrored;

    // Checks if the character is standing still. Used in ChooseAttack() to see if the character should perform a front kick.
    bool front = length_squared(GetTargetVelocity())<0.1f;

    // Check if target is ducking or ragdolled
    vec3 direction = GetAttackDirection();
    float attack_distance = length(direction);
    bool ragdoll_enemy = false;
    bool ducking_enemy = false;
    if(target_id != -1){
        if(ReadCharacterID(target_id).GetIntVar("state")==_ragdoll_state){
            ragdoll_enemy = true;
        }
        if(ReadCharacterID(target_id).GetFloatVar("duck_amount") >= 0.5f){
            ducking_enemy = true;
        }
    }
    
    string attack_path;
    if(attacking_with_throw != 0){
        // Load a throw attack
        if(attacking_with_throw == 1){
            attack_path="Data/Attacks/throw.xml";
        } else if(attacking_with_throw == 2){
            if(weapon_slots[primary_weapon_slot] == -1){
                attack_path="Data/Attacks/rearchoke.xml";
            } else {
                attack_path="Data/Attacks/rearknifecapture.xml";
            }
            executing = false;
        }
    } else {
        // Choose what class of strike to use
        ChooseAttack(front);
        if(curr_attack == "moving" && ragdoll_enemy && weapon_slots[primary_weapon_slot] == -1){
            attack_path = character_getter.GetAttackPath("moving_low");
        } else if(curr_attack == "stationary" ||
           (curr_attack == "moving" && (ducking_enemy || ragdoll_enemy) && weapon_slots[primary_weapon_slot] == -1)){
            if(attack_distance < (_close_attack_range + range_extender * 0.5f) * this_mo.rigged_object().GetCharScale()){
                attack_path = character_getter.GetAttackPath("stationary_close");
            } else {
                attack_path = character_getter.GetAttackPath("stationary");
            }
        } else if(curr_attack == "moving"){
            int primary_weapon_id = weapon_slots[primary_weapon_slot];
            if(primary_weapon_id != -1 && ReadItemID(primary_weapon_id).GetLabel() == "sword" && orig_mirrored == left_handed){
                attack_path = "Data/Attacks/smallswordslashright.xml";
            } else if(attack_distance < (_close_attack_range + range_extender * 0.5f) * this_mo.rigged_object().GetCharScale()){
                attack_path = character_getter.GetAttackPath("moving_close");
            } else {
                attack_path = character_getter.GetAttackPath("moving");
            }
        } else if(curr_attack == "low"){
            attack_path = character_getter.GetAttackPath("low");
        } else if(curr_attack == "air"){
            attack_path = character_getter.GetAttackPath("air");
        }
    }

    // Load selected attack
    attack_getter.Load(attack_path);
    
    if(attack_getter.GetDirection() == _left) {
        mirrored = !mirrored;
    }

    bool flipped = false;
    if(attack_getter.GetDirection() != _front) {
        flipped = mirrored;
    } else {
        flipped = !mirrored_stance;
    }

    if(flipped){
        attack_path += " m";
    }

    attack_getter.Load(attack_path);

    return orig_mirrored;
}

vec3 GetAttackDirection() {
    vec3 direction;
    if(target_id != -1 && ReadCharacterID(target_id).QueryIntFunction("int IsDodging()") == 0){
        direction = ReadCharacterID(target_id).position - this_mo.position;
    } else {
        direction = this_mo.GetFacing();
    }
    return direction;
}

// called when state equals _attack_state
void UpdateAttacking(const Timestep &in ts) {    
    flip_info.UpdateRoll(ts);
    combat_stance_time = time;

    if(target_id != -1){
        vec3 avg_pos = ReadCharacterID(target_id).rigged_object().GetAvgPosition();
        float height_rel = avg_pos.y - (this_mo.position.y+0.45f);
        this_mo.rigged_object().anim_client().SetBlendCoord("attack_height_coord",height_rel);
        //DebugText("height_rel", "height_rel: "+height_rel, 0.5f);
        // Keep a certain distance from ragdolled target
        MovementObject@ target = ReadCharacterID(target_id);
        if(target.GetIntVar("state") == _ragdoll_state){
            vec3 target_pos = ReadCharacterID(target_id).position;
            if(distance(this_mo.position, target_pos) < _leg_sphere_size * 2.0f){
                vec3 dir = normalize(target_pos - this_mo.position);
                this_mo.position = mix(this_mo.position, target_pos - dir * _leg_sphere_size * 2.0f, 0.1f);
            }
        }
    }

    if(on_ground){
        this_mo.velocity *= pow(0.95f,ts.frames());
    } else {
        ApplyPhysics(ts);
    }
    
    vec3 direction = GetAttackDirection();
    direction.y = 0.0f;
    direction = normalize(direction);

    // Rotate spear attacks slightly so they hit center better
    int weapon_id = weapon_slots[primary_weapon_slot];
    if(weapon_id != -1){
        ItemObject@ io = ReadItemID(weapon_id);
        if(io.GetLabel() == "spear"){
            quaternion rotate(vec4(0.0f,1.0f,0.0f,0.05f));
            direction = Mult(rotate, direction);
        }
    }

    if(attack_animation_set){
        if(attack_getter.IsThrow() == 0){
            float attack_facing_inertia = 0.9f;
            if(weapon_slots[primary_weapon_slot] != -1) {
                attack_facing_inertia = 0.8f;
            }
            this_mo.SetRotationFromFacing(InterpDirections(this_mo.GetFacing(),
                                                           direction,
                                                           1.0-pow(attack_facing_inertia,ts.frames())));
            if(WantsToFeint() && can_feint){
                SwitchToBlockedAnim();
                feinting = true;
            }
        } else {
            if(target_id != -1){
                MovementObject @char = ReadCharacterID(target_id);
                char.velocity.x = this_mo.velocity.x;
                char.velocity.z = this_mo.velocity.z;
                tether_dist = 0.4f;
            }
        }
    }
    vec3 right_direction;
    right_direction.x = direction.z;
    right_direction.z = -direction.x;
    if(!on_ground){
        float leg_cannon_target_flip;
        if(target_id != -1){
            float rel_height = normalize(ReadCharacterID(target_id).position - this_mo.position).y;
            leg_cannon_target_flip = -1.4f - rel_height;
        } else {
            leg_cannon_target_flip = -1.4f;
        }
        leg_cannon_flip = mix(leg_cannon_flip, leg_cannon_target_flip, 0.1f);
        flip_modifier_axis = right_direction;
        flip_modifier_rotation = leg_cannon_flip;
    }

    if(attack_animation_set &&
       this_mo.rigged_object().GetStatusKeyValue("cancel")>=1.0f && 
       WantsToCancelAnimation())
    {
        if(cancel_delay <= 0.0f){
            EndAttack();
        }
        cancel_delay -= ts.step();
    } else {
        cancel_delay = 0.01f;
    }

    if(!attack_animation_set){
        bool mirrored = IsAttackMirrored();
        mirrored = LoadAppropriateAttack(mirrored);
        if(attack_getter.GetAsLayer() == 1){
            SetState(_movement_state);
            return;
        }

        if(attack_getter.GetSpecial() == "legcannon"){    
            leg_cannon_flip = 0.0f;
        }

        if(attack_getter.GetHeight() == _low){
            duck_amount = 1.0f;
        } else {
            duck_amount = 0.0f;
        }
        
        if(attack_getter.GetDirection() == _left) {
            mirrored = !mirrored;
        }

        bool mirror = false;
        if(attack_getter.GetDirection() != _front){
            mirror = mirrored;
            mirrored_stance = mirrored;
        } else {
            mirror = mirrored_stance;
        }

        int8 flags = _ANM_FROM_START;
        if(attack_getter.GetMobile() == 1){
            flags = flags | _ANM_MOBILE;
        }
        if(mirror){
            flags = flags | _ANM_MIRRORED;
        }                

        string anim_path;
        if(attack_getter.IsThrow() == 0){
            anim_path = attack_getter.GetUnblockedAnimPath();
            attack_predictability = this_mo.CheckAttackHistory(attack_getter.GetPath());
            this_mo.AddToAttackHistory(attack_getter.GetPath());
            //Print("Updating attack history\n"); 
            //DebugText("test", "Attack predictability: "+attack_predictability, 1.0f);
        } else {
            anim_path = attack_getter.GetThrowAnimPath();
            int hit = _miss;
            if(target_id != -1){
                hit = ReadCharacterID(target_id).WasHit(
                    "grabbed", attack_getter.GetPath(), direction, this_mo.position, this_mo.getID(), p_attack_damage_mult, p_attack_knockback_mult);        
            } else {
                //Print("Grabbing no target\n");
            }
            if(hit == _miss){
                EndAttack();
                return;
            }
            this_mo.SetRotationFromFacing(direction);
        }

        if(!this_mo.controlled){
            this_mo.PlaySoundGroupVoice("attack",0.0f);
        }

        this_mo.SetAnimation(anim_path, 20.0f, flags);
        this_mo.rigged_object().anim_client().SetSpeedMult(p_attack_speed_mult);

        string material_event = attack_getter.GetMaterialEvent();
        if(material_event.length() > 0){
            //Print(material_event);
            this_mo.MaterialEvent(material_event, this_mo.position-vec3(0.0f,_leg_sphere_size, 0.0f));
        }
        if(attack_getter.GetSwapStance() != 0){
            mirrored_stance = !mirrored_stance;
        }
        this_mo.rigged_object().anim_client().SetAnimationCallback("void EndAttack()");
        this_mo.rigged_object().anim_client().SetAnimatedItemID(0, weapon_slots[primary_weapon_slot]);
        attack_animation_set = true;
    }
}

// the animations referred here are mostly blocks, and they're defined in the character-specific XML files.
void UpdateHitReaction(const Timestep &in ts) {
    if(!hit_reaction_anim_set){
        if(hit_reaction_event == "blockprepare"){
            bool right = (attack_getter2.GetDirection() != _left);
            if(attack_getter2.GetMirrored() != 0){
                right = !right;
            }
            if(mirrored_stance){
                right = !right;
            }
            string block_string;
            if(attack_getter2.GetHeight() == _high){
                block_string += "high";
            } else if(attack_getter2.GetHeight() == _medium){
                block_string += "med";
            } else if(attack_getter2.GetHeight() == _low){
                block_string += "low";
            }        
            if(right){
                block_string += "right";
            } else {
                block_string += "left";
            }
            block_string += "block";
            if(mirrored_stance){
                this_mo.SetCharAnimation(block_string,20.0f, _ANM_MIRRORED | _ANM_FROM_START);
            } else {
                this_mo.SetCharAnimation(block_string,20.0f, _ANM_FROM_START);
            }
        } else if(hit_reaction_event == "attackimpact") {
            if(reaction_getter.GetMirrored() == 0 || (reaction_getter.GetMirrored() == 2 && !mirrored_stance)){
                this_mo.SetAnimation(reaction_getter.GetAnimPath(1.0f-block_health),20.0f,_ANM_MOBILE | _ANM_FROM_START);
                mirrored_stance = false;
            } else {
                this_mo.SetAnimation(reaction_getter.GetAnimPath(1.0f-block_health),20.0f,_ANM_MOBILE|_ANM_MIRRORED | _ANM_FROM_START);
                mirrored_stance = true;
            }
        }
        this_mo.rigged_object().anim_client().SetAnimationCallback("void EndHitReaction()");
        hit_reaction_anim_set = true;
        this_mo.rigged_object().anim_client().SetAnimatedItemID(0, weapon_slots[primary_weapon_slot]);
    }
    this_mo.velocity *= pow(0.95f,ts.frames());
    if(this_mo.rigged_object().GetStatusKeyValue("cancel")>=1.0f && WantsToCancelAnimation() && hit_reaction_time > 0.1f){
        EndHitReaction();
    }
    if(this_mo.rigged_object().GetStatusKeyValue("escape")>=1.0f && WantsToCounterThrow()){
        level.SendMessage("character_throw_escape "+this_mo.getID() + " " + target_id);
        this_mo.SwapAnimation(attack_getter2.GetThrownCounterAnimPath());
        this_mo.rigged_object().anim_client().SetAnimationCallback("void EndHitReaction()");
        string sound = "Data/Sounds/weapon_foley/swoosh/weapon_whoos_big.xml";
        this_mo.PlaySoundGroupAttached(sound,this_mo.position);
        //TimedSlowMotion(0.1f,0.3f, 0.1f);
    }
    hit_reaction_time += ts.step();
}

void PlayStandAnimation(bool blocked) {
    int8 flags = _ANM_MOBILE;
    if(left_handed){
        flags |= _ANM_MIRRORED;
    }
    mirrored_stance = left_handed;
    if(!blocked){ 
        if(wake_up_torso_front.y < 0){
            this_mo.SetAnimation("Data/Animations/r_standfromfront.anm", 20.0f, flags);
        } else {
            this_mo.SetAnimation("Data/Animations/r_standfromback2.anm", 20.0f, flags);
        }
    } else {
        this_mo.SetAnimation("Data/Animations/r_blockfrontfromground.anm", 200.0f, flags);
    }
    this_mo.rigged_object().anim_client().SetAnimationCallback("void EndGetUp()");
    this_mo.SetRotationFromFacing(normalize(vec3(wake_up_torso_up.x,0.0f,wake_up_torso_up.z))*-1.0f);
    getting_up_time = 0.0f;  
}

array<mat4> ragdoll_pose;
float unragdoll_time = 0.0f;

void SetState(int _state) {
    if(state == _ragdoll_state && _state != _ragdoll_state){
        unragdoll_time = time - time_step;
        this_mo.UnRagdoll();
        ResetSecondaryAnimation();
        Skeleton @skeleton = this_mo.rigged_object().skeleton();
        ragdoll_pose.resize(skeleton.NumBones());
        for(int i=0, len=skeleton.NumBones(); i<len; ++i){
            if(skeleton.HasPhysics(i)){
                ragdoll_pose[i] = skeleton.GetBoneTransform(i);
            }
        }
    }
    state = _state;
    if(state == _movement_state){
        StartFootStance();
    } else {
        stance_move = false;
    }
    if(state != _attack_state){
        curr_attack = "";
    }
    if(state == _hit_reaction_state){
        active_block_anim = false;
        hit_reaction_time = 0.0f;
        hit_reaction_anim_set = false;
        hit_reaction_thrown = false;
        hit_reaction_dodge = false;
        flip_modifier_rotation = 0.0f;
    }
}

// WakeUp is called when a character gets out of the ragdoll mode. 
void WakeUp(int how) {
    mat4 torso_transform = this_mo.rigged_object().GetAvgIKChainTransform("torso");
    wake_up_torso_front = torso_transform.GetColumn(1);
    wake_up_torso_up = torso_transform.GetColumn(2);
    ragdoll_cam_recover_time = 1.0f;

    SetState(_movement_state);
    
    HandleBumperCollision();
    HandleStandingCollision();
    this_mo.position = sphere_col.position;

    duck_amount = 1.0f;
    duck_vel = 0.0f;
    target_duck_amount = 1.0f;
    if(how == _wake_stand || how == _wake_block_stand){
        SetOnGround(true);
        flip_info.Land();
        SetState(_ground_state);
        PlayStandAnimation(how == _wake_block_stand);
        ragdoll_cam_recover_speed = 2.0f;
        if(how != _wake_block_stand){
            ragdoll_fade_speed = 1.0f;
        } else {
            ragdoll_fade_speed = 40.0f;
        }
        target_duck_amount = 0.0f;
    } else if(how == _wake_fall){
        SetOnGround(true);
        flip_info.Land();
        ApplyIdle(5.0f, true);
        ragdoll_cam_recover_speed = 10.0f;
        ragdoll_fade_speed = 4.0f;
    } else if (how == _wake_flip) {
        SetOnGround(false);
        jump_info.StartFall();
        flip_info.StartFlip();
        flip_info.FlipRecover();
        this_mo.SetCharAnimation("jump", 5.0f, _ANM_FROM_START);
        ragdoll_cam_recover_speed = 100.0f;
        ragdoll_fade_speed = 4.0f;
    } else if (how == _wake_roll) {
        SetOnGround(true);
        flip_info.Land();
        ApplyIdle(5.0f, true);
        vec3 roll_dir = GetTargetVelocity();
        vec3 flat_vel = vec3(this_mo.velocity.x, 0.0f, this_mo.velocity.z);
        if(length(flat_vel)>1.0f){
            roll_dir = normalize(flat_vel);
        }
        flip_info.StartRoll(roll_dir);
        ragdoll_cam_recover_speed = 10.0f;
        ragdoll_fade_speed = 2.0f;
    }
}

bool CanRoll() {
    vec3 sphere_center = this_mo.position;
    float radius = 1.0f;
    col.GetSlidingSphereCollision(sphere_center, radius);
    bool can_roll = true;
    vec3 roll_point;
    if(sphere_col.NumContacts() == 0){
        can_roll = false;
    } else {
        can_roll = false;
        roll_point = sphere_col.GetContact(0).position;
        for(int i=0; i<sphere_col.NumContacts(); i++){
            const CollisionPoint contact = sphere_col.GetContact(i);
            if(contact.position.y < roll_point.y){
                roll_point = contact.position;
            }
            if(contact.normal.y > 0.5f){
                can_roll = true;
            }
        }
    }
    return can_roll;
}

void EndGetUp(){
    if(state == _ground_state){
        SetState(_movement_state);
        duck_amount = 1.0f;
        duck_vel = 0.0f;
        target_duck_amount = 1.0f;
    }
}

void HandleGroundStateCollision() {
    HandleBumperCollision();
    HandleStandingCollision();
    this_mo.position = sphere_col.position;
    if(sphere_col.NumContacts() == 0){
        this_mo.position.y -= 0.1f;
    }
    for(int i=0; i<sphere_col.NumContacts(); i++){
        const CollisionPoint contact = sphere_col.GetContact(i);
        if(distance(contact.position, this_mo.position)<=_leg_sphere_size+0.01f){
            ground_normal = ground_normal * 0.9f +
                            contact.normal * 0.1f;
            ground_normal = normalize(ground_normal);
        }
    }
}

// Nothing() does nothing.
void Nothing() {
}

// Called only when state equals _ground_state
void UpdateGroundState(const Timestep &in ts) {
    this_mo.velocity = vec3(0.0f);
    //this_mo.velocity = GetTargetVelocity() * _walk_accel * 0.15f;
    
    HandleGroundStateCollision();
    getting_up_time += ts.step();
}

void DecalCheck(){
    /*DebugDrawWireSphere(left_decal_pos,
                        0.1f,
                        vec3(1.0f),
                        _delete_on_update);*/
    if(!feet_moving || length_squared(this_mo.velocity) < 0.3f){
        vec3 curr_left_decal_pos = this_mo.rigged_object().GetIKTargetPosition("left_leg");
        vec3 curr_right_decal_pos = this_mo.rigged_object().GetIKTargetPosition("right_leg");
        /*DebugDrawWireSphere(curr_left_decal_pos,
                        0.1f,
                        vec3(1.0f),
                        _delete_on_update);*/
        if(distance(curr_left_decal_pos, left_decal_pos) > _dist_threshold){
            if(left_smear_time < _smear_time_threshold){
                //this_mo.ChangeLastMaterialDecalDirection("left_leg",curr_left_decal_pos - left_decal_pos);
            } 
            /*if(smear_sound_time > 0.1f){
                PlaySoundGroup("Data/Sounds/footstep_mud.xml", curr_left_decal_pos);
                smear_sound_time = 0.0f;
            }*/
            //this_mo.rigged_object().MaterialDecalAtBone("step","left_leg");
            this_mo.MaterialParticleAtBone("skid","left_leg");
            left_decal_pos = curr_left_decal_pos;
            left_smear_time = 0.0f;
        }
        if(distance(curr_right_decal_pos, right_decal_pos) > _dist_threshold){
            if(right_smear_time < _smear_time_threshold){
                //this_mo.ChangeLastMaterialDecalDirection("right_leg",curr_right_decal_pos - right_decal_pos);
            }
            /*if(smear_sound_time > 0.1f){
                PlaySoundGroup("Data/Sounds/footstep_mud.xml", curr_left_decal_pos);
                smear_sound_time = 0.0f;
            }*/
            right_decal_pos = curr_right_decal_pos;
            //this_mo.rigged_object().MaterialDecalAtBone("step","right_leg");
            this_mo.MaterialParticleAtBone("skid","right_leg");
            right_smear_time = 0.0f;
        }
    }
}

void Execute(ExecutionType type) {
    being_executed = type;
}

void HandleCollisionsBetweenTwoCharacters(MovementObject @other){
    if(state == _ragdoll_state || 
       reset_no_collide > the_time - 0.2f ||
       other.GetIntVar("state") == _ragdoll_state ||
       (state == _attack_state && attack_getter.IsThrow() == 1) ||
       (state == _hit_reaction_state && attack_getter2.IsThrow() == 1) ||
       (tethered != _TETHERED_FREE && other.getID() == tether_id))
    {
        return;
    }

    if(knocked_out == _awake && other.GetIntVar("knocked_out") == _awake){
        float distance_threshold = 0.7f;
        vec3 this_com = this_mo.rigged_object().skeleton().GetCenterOfMass();
        vec3 other_com = other.rigged_object().skeleton().GetCenterOfMass();
        this_com.y = this_mo.position.y;
        other_com.y = other.position.y;
        if(distance_squared(this_com, other_com) < distance_threshold*distance_threshold){
            vec3 dir = other_com - this_com;
            float dist = length(dir);
            dir /= dist;
            dir *= distance_threshold - dist;
            other.position += dir * 0.5f;
            this_mo.position -= dir * 0.5f;
                
            vec3 other_push = dir * 0.5f / (time_step) * 0.15f;
            push_velocity -= other_push;
            other.Execute("push_velocity += vec3("+other_push.x+","+other_push.y+","+other_push.z+");");
            other.Execute("MindReceiveMessage(\"collided "+this_mo.GetID()+"\");");
        }    
    }
    MindReceiveMessage("collided "+other.GetID());
}

void UpdatePrimaryWeapon(){
    int primary_weapon_id = weapon_slots[primary_weapon_slot];
    this_mo.rigged_object().SetPrimaryWeaponID(primary_weapon_id);
    if(primary_weapon_id == -1){
        range_extender = 0.0f;
        range_multiplier = 1.0f;
    } else {
        ItemObject@ item_obj = ReadItemID(primary_weapon_id);
        range_extender = item_obj.GetRangeExtender();
        range_multiplier = item_obj.GetRangeMultiplier();
    }
    this_mo.UpdateWeapons();
}

void UpdateItemFistGrip(){
    if(weapon_slots[_held_left] != -1){
        this_mo.rigged_object().SetMorphTargetWeight("fist_l",1.0f,1.0f);
    } else {
        this_mo.rigged_object().SetMorphTargetWeight("fist_l",1.0f,0.0f);
    }
    if(weapon_slots[_held_right] != -1){
        this_mo.rigged_object().SetMorphTargetWeight("fist_r",1.0f,1.0f);
    } else {
        this_mo.rigged_object().SetMorphTargetWeight("fist_r",1.0f,0.0f);
    }
}

void NotifyItemDetach(int item_id){
    if(weapon_slots[primary_weapon_slot] == item_id) {
        weapon_slots[primary_weapon_slot] = -1;
        UpdatePrimaryWeapon();
    }
    for(int i=0; i<6; ++i){
        if(weapon_slots[i] == item_id){
            weapon_slots[i] = -1;
        }
    }
    UpdateItemFistGrip();
}

int DropWeapon() {
    int dropped_item = -1;
    if(weapon_slots[_held_left] != -1){
        dropped_item = weapon_slots[_held_left];
        this_mo.DetachItem(weapon_slots[_held_left]);
        weapon_slots[_held_left] = -1;
    } else if(weapon_slots[_held_right] != -1){
        dropped_item = weapon_slots[_held_right];
        this_mo.DetachItem(weapon_slots[_held_right]);
        weapon_slots[_held_right] = -1;
    }
    if(pickup_layer != -1){
        this_mo.rigged_object().anim_client().RemoveLayer(pickup_layer, 4.0f);
        pickup_layer = -1;
    }
    UpdateItemFistGrip();
    UpdatePrimaryWeapon();
    return dropped_item;
}

vec3 CalcLaunchVel(vec3 start, vec3 end, float mass, vec3 vel, vec3 targ_vel, float&out time) {
    vec3 dir = normalize(end - start);
    vec3 flat_dir = normalize(vec3(dir.x, 0.0f, dir.z));
    float flat_launch_speed = _base_launch_speed / max(1.0f,mass) +
                              dot(flat_dir, this_mo.velocity);
    float max_up_speed = this_mo.velocity.y + _base_up_speed / max(1.0f,mass);
    float arc = 0.0f;
    vec3 launch_vel = GetVelocityForTarget(start, end, flat_launch_speed, max_up_speed, arc, time);
    launch_vel = GetVelocityForTarget(start, end + targ_vel*time, flat_launch_speed, max_up_speed, arc, time);
    launch_vel = GetVelocityForTarget(start, end + targ_vel*time, flat_launch_speed, max_up_speed, arc, time);
    if(launch_vel == vec3(0.0f)){
        launch_vel = flat_launch_speed * flat_dir + vec3(0.0f,max_up_speed,0.0f);
    }
    if(length(launch_vel) > flat_launch_speed + max_up_speed){
        launch_vel = normalize(launch_vel) * (flat_launch_speed + max_up_speed);
    }
    return launch_vel;
}

void ThrowWeapon() {
    if(weapon_slots[primary_weapon_slot] != -1){
        int target = target_id;
        //if(target != -1){
            int weapon_id = weapon_slots[primary_weapon_slot];
            this_mo.DetachItem(weapon_id);
            weapon_slots[primary_weapon_slot] = -1;
            ItemObject@ io = ReadItemID(weapon_id);
            float time;
            // Apply velocity needed for item to reach target
            vec3 start = io.GetPhysicsPosition();
            vec3 end = this_mo.position + this_mo.GetFacing() * 100.0f;
            vec3 target_vel;
            if(target_id != -1){
                MovementObject@ char = ReadCharacterID(target);
                end = char.rigged_object().GetAvgIKChainPos("torso");
                target_vel = char.velocity;
            }
            float effective_mass = io.GetMass();
            if(io.GetLabel() == "big_sword" && throw_anim){
                effective_mass *= 0.25f;
            }
            if(io.GetLabel() == "spear" && throw_anim){
                effective_mass *= 0.25f;
            }
            vec3 launch_vel = CalcLaunchVel(start, end, effective_mass, this_mo.velocity, target_vel, time);
            io.SetLinearVelocity(launch_vel);
            // Determine angular velocity to end up hitting point-first
            vec3 ang_vel = io.GetAngularVelocity();
            vec3 dir = normalize(end - start);
            vec3 twist_ang_vel = dir * dot(ang_vel, dir);
            ang_vel = ang_vel - twist_ang_vel;
            float num_turns = floor(time * 2.0f / io.GetMass()) + 0.25f;
            io.SetThrown();
            if(io.GetLabel() == "big_sword" && throw_anim){
                vec3 flat_dir = dir;
                flat_dir.y = 0.0f;
                flat_dir = normalize(flat_dir);
                vec3 perp_dir(-flat_dir.z, 0.0f, flat_dir.x);
                io.SetAngularVelocity(perp_dir * -10.0f);
            } else if(io.GetLabel() == "spear" && throw_anim){
                io.SetThrownStraight();
            } else {
                io.SetAngularVelocity((normalize(ang_vel)* 6.28318f * num_turns)/time + twist_ang_vel);
            }
            // Apply opposite force to character
            //this_mo.velocity -= launch_vel * io.GetMass() * 0.05f;
            UpdatePrimaryWeapon();
            UpdateItemFistGrip();
        //}
    }
}

int GetNumHandsFree() {
    int hands_free = 2;
    if(weapon_slots[primary_weapon_slot] != -1){
        ItemObject@ item_obj = ReadItemID(weapon_slots[primary_weapon_slot]);
        hands_free -= item_obj.GetNumHands();
    }
    if(weapon_slots[secondary_weapon_slot] != -1){
        ItemObject@ item_obj = ReadItemID(weapon_slots[secondary_weapon_slot]);
        hands_free -= item_obj.GetNumHands();
    }
    return hands_free;
}

int GetNearestPickupableWeapon(vec3 point, float max_range){
    int num_items = GetNumItems();
    int closest_id = -1;
    float closest_dist = 0.0f;
    int hands_free = GetNumHandsFree();
    for(int i=0; i<num_items; i++){
        ItemObject@ item_obj = ReadItem(i);
        if(item_obj.GetType() == _misc){
            continue;
        }
        if(item_obj.GetNumHands() > hands_free){
            continue;
        }
        if(item_obj.IsHeld()){
            int holder_id = item_obj.HeldByWhom();
            if(holder_id == -1){
                continue;
            }    
            MovementObject@ holder = ReadCharacterID(holder_id);
            if(holder.GetIntVar("knocked_out") == _awake){
                continue;
            }
        }
        vec3 item_pos = item_obj.GetPhysicsPosition();
        if(closest_id == -1 || distance_squared(point, item_pos) < closest_dist){ 
            closest_dist = distance_squared(point, item_pos);
            closest_id = item_obj.GetID();
        }
    }
    if(closest_dist < max_range*max_range){
        return closest_id;
    } else {
        return -1;
    }
}

int GetNearestThrownWeapon(vec3 point, float max_range){
    int num_items = GetNumItems();
    int closest_id = -1;
    float closest_dist = 0.0f;
    for(int i=0; i<num_items; i++){
        ItemObject@ item_obj = ReadItem(i);
        if(item_obj.IsHeld() || item_obj.CheckThrownSafe()){
            continue;
        }
        vec3 item_pos = item_obj.GetPhysicsPosition();
        if(closest_id == -1 || distance_squared(point, item_pos) < closest_dist){ 
            closest_dist = distance_squared(point, item_pos);
            closest_id = item_obj.GetID();
        }
    }
    if(closest_dist < max_range*max_range){
        return closest_id;
    } else {
        return -1;
    }
}

void StartSheathing(int slot){
    ItemObject @obj = ReadItemID(weapon_slots[slot]);
    bool prefer_same_side = obj.GetMass() < 0.55f;
    int side_a, side_b;
    if( (prefer_same_side && slot == _held_right) ||
       (!prefer_same_side && slot != _held_right))
    {
        side_a = _sheathed_right;
        side_b = _sheathed_left;
    } else {
        side_a = _sheathed_left;
        side_b = _sheathed_right;
    }
    int dst = -1;
    // Put weapon in sheathe if possible, otherwise put in empty slot
    if(weapon_slots[side_a] != -1 && DoesItemFitInItem(weapon_slots[slot], weapon_slots[side_a])){
        dst = side_a;
    } else if(weapon_slots[side_b] != -1 && DoesItemFitInItem(weapon_slots[slot], weapon_slots[side_b])){
        dst = side_b;
    } else if(weapon_slots[side_a] == -1){
        dst = side_a;
    } else if(weapon_slots[side_b] == -1){
        dst = side_b;
    }
    //slot = _held_left;
    //dst = _sheathed_left;
    if(dst != -1){
        int flags = 0;
        if(slot == _held_left){
            flags = _ANM_MIRRORED;
        }
        if((slot == _held_left && dst == _sheathed_right) ||
           (slot == _held_right && dst == _sheathed_left))
        {
            ItemObject@ item_obj = ReadItemID(weapon_slots[slot]);
            if(item_obj.HasSheatheAttachment()){
                sheathe_layer_id = this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_knifesheathe.anm",8.0f,flags);
                this_mo.rigged_object().anim_client().SetLayerItemID(sheathe_layer_id, 0, weapon_slots[slot]);
            }
        } else {
            ItemObject@ item_obj = ReadItemID(weapon_slots[slot]);
            if(item_obj.HasSheatheAttachment()){
                sheathe_layer_id = this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_knifesheathesameside.anm",8.0f,flags);
                this_mo.rigged_object().anim_client().SetLayerItemID(sheathe_layer_id, 0, weapon_slots[slot]);
            }
        }
    }
}

void HandleThrow() {
    if(WantsToThrowItem() && weapon_slots[primary_weapon_slot] != -1 && throw_knife_layer_id == -1){        
        float throw_range = 50.0f;
        int target = GetClosestCharacterID(throw_range, _TC_ENEMY | _TC_CONSCIOUS | _TC_NON_RAGDOLL);
        if(target != -1 && (on_ground || flip_info.IsFlipping())){
            SetTargetID(target);
            going_to_throw_item = true;
            going_to_throw_item_time = time;
        }
    }
    if(going_to_throw_item && going_to_throw_item_time <= time && going_to_throw_item_time > time - 1.0f){
        if(!flip_info.IsFlipping() || flip_info.flip_progress > 0.5f){
            int8 flags = 0;
            if(primary_weapon_slot == _held_left){
                flags |= _ANM_MIRRORED;   
            }
            int primary_weapon_id = weapon_slots[primary_weapon_slot];
            string label = ReadItemID(primary_weapon_id).GetLabel();
            if(on_ground && !flip_info.IsFlipping() && primary_weapon_id != -1 && (label == "big_sword" || label == "spear")){
                SetState(_attack_state);
                can_feint = false;
                feinting = false;
                flags = _ANM_FROM_START | _ANM_MOBILE;
                if(mirrored_stance){
                    flags |= _ANM_MIRRORED;
                }
                //this_mo.velocity = vec3(0.0f);
                mirrored_stance = !mirrored_stance;
                if(label == "big_sword"){
                    this_mo.SetAnimation("Data/Animations/r_dogswordthrow.anm", 10.0f, flags);
                } else if(label == "spear"){
                    this_mo.SetAnimation("Data/Animations/r_spearthrow.anm", 10.0f, flags);
                }
                attack_getter.Load(character_getter.GetAttackPath("stationary")); // Set attack to a normal attack so faces enemy correctly
                this_mo.rigged_object().anim_client().SetAnimationCallback("void EndAttack()");
                this_mo.rigged_object().anim_client().SetAnimatedItemID(0, weapon_slots[primary_weapon_slot]);
                attack_animation_set = true;
                attacking_with_throw = 0;
                throw_anim = true;
            } else {
                if(!flip_info.IsFlipping()){
                    throw_knife_layer_id = this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_knifethrowlayer.anm",8.0f,flags);
                } else {
                    throw_knife_layer_id = this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_knifethrowfliplayer.anm",8.0f,flags);
                }
                throw_anim = false;
            }
            going_to_throw_item = false;
        }
    }
}

void HandlePickUp() {
    if((WantsToDropItem() && throw_knife_layer_id == -1) || knocked_out != _awake){
        DropWeapon();
    }
    if(knocked_out != _awake || state == _ragdoll_state || tethered != _TETHERED_FREE){
        return;
    }
    if(active_blocking){
        int nearest_thrown_id = GetNearestThrownWeapon(this_mo.position, 2.0f);
        if(nearest_thrown_id != -1){
            ItemObject@ io = ReadItemID(nearest_thrown_id);
            vec3 vel = io.GetLinearVelocity();
            if(length_squared(vel) > 5.0f && dot(this_mo.GetFacing(), vel) < 0.0f){
                if(io.GetNumHands() > GetNumHandsFree()){
                    ParryItem(nearest_thrown_id);
                } else {
                    CatchItem(nearest_thrown_id);
                }
            }
        }
    }
    if(WantsToPickUpItem()){
        if(weapon_slots[primary_weapon_slot] == -1 || weapon_slots[secondary_weapon_slot] == -1){
            vec3 hand_pos;
            if(weapon_slots[_held_right] == -1 && (primary_weapon_slot == _held_right || weapon_slots[_held_left] != -1)){
                hand_pos = this_mo.rigged_object().GetIKTargetTransform("rightarm").GetTranslationPart();
            } else {
                hand_pos = this_mo.rigged_object().GetIKTargetTransform("leftarm").GetTranslationPart();
            }
            int nearest_weapon = GetNearestPickupableWeapon(hand_pos, 0.9f);
            if(nearest_weapon != -1){
                ItemObject@ item_obj = ReadItemID(nearest_weapon);
                vec3 pos = item_obj.GetPhysicsPosition();
                if(flip_info.IsFlipping()){
                    int stuck_id = item_obj.StuckInWhom();
                    if(stuck_id != -1){
                        GrabWeaponFromBody(stuck_id, item_obj.GetID(), pos);
                    }
                    AttachWeapon(item_obj.GetID());
                } else {
                    if(pickup_layer == -1){
                        int flags = 0;
                        if(!(weapon_slots[_held_right] == -1 && (primary_weapon_slot == _held_right || weapon_slots[_held_left] != -1))){
                            flags |= _ANM_MIRRORED;
                        }
                        pickup_layer = this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_pickup.anm",4.0f,flags);
                        pickup_layer_attempts = 0;
                    }
                }
            }
        }
        if(weapon_slots[primary_weapon_slot] == -1 || weapon_slots[secondary_weapon_slot] == -1){
            int nearest_weapon = GetNearestPickupableWeapon(this_mo.position, _pick_up_range);
            if(nearest_weapon != -1){
                ItemObject@ item_obj = ReadItemID(nearest_weapon);
                vec3 pos = item_obj.GetPhysicsPosition();
                vec3 flat_dir = pos-this_mo.position;
                flat_dir.y = 0.0f;
                if(length_squared(flat_dir) > 1.0f){
                    flat_dir = normalize(flat_dir);
                }
                target_duck_amount = max(target_duck_amount,1.0f-length_squared(flat_dir));
                get_weapon_dir = flat_dir;
                get_weapon_pos = pos;
                trying_to_get_weapon = 2;
                trying_to_get_weapon_time = 0.0f;
            }
        }
    } else {
        if(pickup_layer != -1){
            this_mo.rigged_object().anim_client().RemoveLayer(pickup_layer, 4.0f);
            pickup_layer = -1;
        } 
    }
    if(sheathe_layer_id == -1){
        int src;
        if(WantsToSheatheItem() && weapon_slots[primary_weapon_slot] != -1){ 
            StartSheathing(primary_weapon_slot);
        } else if(WantsToUnSheatheItem(src) && weapon_slots[primary_weapon_slot] == -1){
            if(src != -1){
                int flags = 0;
                if(primary_weapon_slot == _held_left){
                    flags = _ANM_MIRRORED;
                }
                if((primary_weapon_slot == _held_left && src == _sheathed_right) ||
                   (primary_weapon_slot == _held_right && src == _sheathed_left))
                {
                    sheathe_layer_id = this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_knifeunsheathe.anm",8.0f,flags);
                } else {
                    sheathe_layer_id = this_mo.rigged_object().anim_client().AddLayer("Data/Animations/r_knifeunsheathesameside.anm",8.0f,flags);
                }
            }
        }
    }
}

array<int> GetPlayerCharacterIDs() {
    array<int> ids;
    int num = GetNumCharacters();
    for(int i=0; i<num; ++i){
        MovementObject@ char = ReadCharacter(i);
        if(char.controlled){
            ids.push_back(char.GetID());
        }
    }
    return ids;
}

void ApplyCameraControls(const Timestep &in ts) {
    if(!level.HasFocus()){
        SetGrabMouse(true);
    }
    if(level.QueryIntFunction("int HasCameraControl()") == 1){
        return;
    }

    // Get array of players
    array<int> player_ids = GetPlayerCharacterIDs();
    int num_players = player_ids.size();
    
    bool shared_cam = !GetSplitscreen() && num_players >= 2;

    const float kCameraRotationInertia = 0.5f;
    const float kCamFollowDistance = 2.0f * this_mo.rigged_object().GetCharScale();
    const float kCamCollisionRadius = 0.15f;

    // Get camera position
    vec3 cam_pos;
    if(!shared_cam){
        vec3 cam_center;
        // Use collision check to keep camera center away from level geometry
        // especially during ragdoll
        vec3 dir = normalize(vec3(0.0f,1.0f,0.0f)-this_mo.GetFacing());
        float sphere_check_radius = _leg_sphere_size*0.75f;
        vec3 sphere_check_offset = dir*_leg_sphere_size*0.25f;
        col.GetSlidingSphereCollision(this_mo.position + sphere_check_offset, sphere_check_radius);
        cam_pos = sphere_col.adjusted_position - sphere_check_offset;
        // cam_pos_offset is used to smooth camera movement when entering edge grab
        cam_pos += cam_pos_offset;
        // Move camera center upwards, and use collision check to avoid obstacles
        if(state != _ragdoll_state){
            vec3 cam_offset;
            if(on_ground){
                cam_offset = vec3(0.0f,mix(0.6f,0.4f,duck_amount),0.0f);
            } else {
                cam_offset = vec3(0.0f,0.6f,0.0f);
            }
            col.GetSweptSphereCollision(cam_pos, cam_pos+cam_offset*this_mo.rigged_object().GetCharScale(), kCamCollisionRadius);
            cam_pos = sphere_col.position;
        } else {
            cam_pos += vec3(0.0f,0.3f,0.0f);
        }
    } else if(shared_cam){
        // Set camera focus to midpoint of bounding box of character positions
        MovementObject @char_a = ReadCharacterID(player_ids[0]);
        vec3 min_coord = char_a.position;
        vec3 max_coord = char_a.position;
        for(int i=1; i<num_players; ++i){
            MovementObject @char_b = ReadCharacterID(player_ids[i]);
            for(int j=0; j<3; ++j){
                min_coord[j] = min(min_coord[j],char_b.position[j]);
                max_coord[j] = max(max_coord[j],char_b.position[j]);
            }
        }
        cam_pos = (min_coord+max_coord)*0.5f + vec3(0.0f,0.6f,0.0f);
    }

    if(!camera.GetAutoCamera()){
        if(!level.HasFocus() && cam_input){   
            // Handle direct camera rotation control
            target_rotation -= GetLookXAxis(this_mo.controller_id);
            target_rotation2 -= GetLookYAxis(this_mo.controller_id);   
        }
    } else {  // Handle assisted camera AI
        // Interpolate camera facing
        vec3 target_chase_cam_pos = cam_pos - camera.GetFacing() * cam_distance;
        autocam.chase_cam_pos = mix(target_chase_cam_pos, autocam.chase_cam_pos, pow(0.9f, ts.frames()));
        vec3 facing = normalize(cam_pos - autocam.chase_cam_pos);

        if(target_id != -1){
            // Look at target character
            MovementObject @char = ReadCharacterID(target_id);
            float dist = distance(char.position, this_mo.position);
            vec3 target_facing = (char.position - this_mo.position)/dist;
            // We want more of a side view at close range, and more of a straight view in the distance
            float target_angle = max(0.2f, 1.2f / max(1.0f,dist)); 
            if(autocam.target_weight == 0.0f){
                autocam.angle = target_angle;
            } else {
                autocam.angle = mix(target_angle, autocam.angle, pow(0.98f, ts.frames()));
            }
            mat4 rotation_y;
            rotation_y.SetRotationY(autocam.angle);
            vec3 target_facing_right = rotation_y * target_facing;
            rotation_y.SetRotationY(-autocam.angle);
            vec3 target_facing_left = rotation_y * target_facing;

            // Check which side angle is closest to the current camera angle
            if(dot(target_facing_left, facing) > dot(target_facing_right, facing)){
                target_facing = target_facing_left;
                if(autocam.target_weight == 0.0f){
                    autocam.target_side_weight = 0.0f;
                } else {
                    autocam.target_side_weight = mix(0.0f, autocam.target_side_weight, pow(0.95f, ts.frames()));
                }
            } else {
                if(autocam.target_weight == 0.0f){
                    autocam.target_side_weight = 1.0f;
                } else {
                    autocam.target_side_weight = mix(1.0f, autocam.target_side_weight, pow(0.95f, ts.frames()));
                }
            }
            target_facing = mix(target_facing_left, target_facing_right, autocam.target_side_weight);
            // Character target is applied more strongly the closer it is
            float target_target_weight = 1.0f/dist;
            target_target_weight = max(0.0f,min(1.0f,target_target_weight*3.0f));
            if(target_target_weight <= 0.3f){
                target_target_weight = 0.0f;
            }
            autocam.target_weight = mix(target_target_weight, autocam.target_weight, pow(0.98f, ts.frames()));
            if(autocam.target_weight < 0.01f && target_target_weight == 0.0f){
                autocam.target_weight = 0.0f;
            }
            facing = InterpDirections(facing, target_facing, autocam.target_weight);
       }

       // Store current target rotations in case we want to override autocam changes
       float old_tr = target_rotation;
       float old_tr2 = target_rotation2;

       // Apply vertical angle
       float facing_rotation2 = asin(facing.y)/3.14159265f * 180.0f;
       target_rotation2 = mix(facing_rotation2,
                              target_rotation2,
                              pow(0.95f, ts.frames()));
       // Apply horizontal camera angle
       facing.y = 0.0f;
       if(length_squared(facing) > 0.01f){
            facing = normalize(facing);
            target_rotation = atan2(-facing.x,-facing.z)/3.14159265f * 180.0f;
       }
       while(target_rotation < cam_rotation - 180.0f){
            target_rotation += 360.0f;
       } 
       while(target_rotation > cam_rotation + 180.0f){
            target_rotation -= 360.0f;
       }

       // Revert changes partly based on auto_cam_override
        target_rotation = mix(target_rotation, old_tr, min(1.0f,auto_cam_override));
        target_rotation2 = mix(target_rotation2, old_tr2, min(1.0f,auto_cam_override));

        // Apply manual camera rotation input
        if(cam_input){
            target_rotation -= GetLookXAxis(this_mo.controller_id);
            target_rotation2 -= GetLookYAxis(this_mo.controller_id); 
        }

        // Reduce auto_cam_override over time, or add to it if received manual camera input
        auto_cam_override *= pow(0.99f, ts.frames());
        if(cam_input){
            auto_cam_override += abs(GetLookXAxis(this_mo.controller_id))*0.05f + abs(GetLookYAxis(this_mo.controller_id))*0.05f;
        }
        auto_cam_override = min(2.5f, auto_cam_override);
    }

    // Clamp vertical rotation to reasonable levels
    target_rotation2 = max(-90.0f,min(50.0f,target_rotation2));

    if(shared_cam){
        if(num_players == 2){
            // Set rotation to look at characters from the side
            MovementObject @char_a = ReadCharacterID(player_ids[0]);
            MovementObject @char_b = ReadCharacterID(player_ids[1]);
            vec3 vec = normalize(char_b.position - char_a.position);
            target_rotation = atan2(vec.x, vec.z) * 180.0f / 3.1415f + 90.0f;

            // Change rotation to have minimum difference from current rotation
            while(target_rotation < cam_rotation - 180.0f){
                target_rotation += 360.0f;
            } 
            while(target_rotation > cam_rotation + 180.0f){
                target_rotation -= 360.0f;
            }
            while(target_rotation < cam_rotation - 90.0f){
                target_rotation += 180.0f;
            } 
            while(target_rotation > cam_rotation + 90.0f){
                target_rotation -= 180.0f;
            }

            // Cap rotation amount
            float kMaxAngleChange = 3.0f;
            if(target_rotation > cam_rotation + kMaxAngleChange){
                target_rotation = cam_rotation + kMaxAngleChange;
            }
            if(target_rotation < cam_rotation - kMaxAngleChange){
                target_rotation = cam_rotation - kMaxAngleChange;
            }

            // If either character is not visible, raise camera angle
            target_rotation2 = shared_cam_elevation;
            if(!char_b.VisibilityCheck(cam_pos - camera.GetFacing() * cam_distance)){
                target_shared_cam_elevation -= 1.0f;
            }
            if(!char_a.VisibilityCheck(cam_pos - camera.GetFacing() * cam_distance)){
                target_shared_cam_elevation -= 1.0f;
            }
            shared_cam_elevation = mix(target_shared_cam_elevation, shared_cam_elevation, 0.99f);
            target_shared_cam_elevation = mix(0.0f, target_shared_cam_elevation, 0.99f);
        } else {
            target_rotation = 0.0f;
            target_rotation2 = -90.0f;
        }
    }

    if(!shared_cam){
        ApplyCameraCones(cam_pos);
    }

    // Apply camera rotation with inertia
    float inertia = pow(kCameraRotationInertia, ts.frames());
    cam_rotation = cam_rotation * inertia + 
               target_rotation * (1.0f - inertia);
    cam_rotation2 = cam_rotation2 * inertia + 
               target_rotation2 * (1.0f - inertia);
    
    if(old_cam_pos == vec3(0.0f)){
        old_cam_pos = camera.GetPos();
    }
    if(!shared_cam){
        old_cam_pos += this_mo.velocity * ts.step();
    }

    // Transition from ragdoll camera back to normal camera
    if(ragdoll_cam_recover_time > 0.0f){
        cam_pos = mix(cam_pos, ragdoll_cam_pos, ragdoll_cam_recover_time);
        ragdoll_cam_recover_time -= ts.step() * ragdoll_cam_recover_speed;
    }

    // Apply camera position inertia
    cam_pos = mix(cam_pos,old_cam_pos,0.8f);

    camera.SetVelocity(this_mo.velocity); 

    {
        vec3 facing;
        mat4 rotationY_mat,rotationX_mat;
        rotationY_mat.SetRotationY(cam_rotation*3.1415f/180.0f);
        rotationX_mat.SetRotationX(cam_rotation2*3.1415f/180.0f);
        mat4 rotation_mat = rotationY_mat * rotationX_mat;
        facing = rotation_mat * vec3(0.0f,0.0f,-1.0f);
        // Check for collisions between camera center and camera follow position
        vec3 cam_follow_pos = cam_pos - facing * kCamFollowDistance;
        col.GetSweptSphereCollision(cam_pos,cam_follow_pos, kCamCollisionRadius);    
    }

    float target_cam_distance = kCamFollowDistance;
    if(sphere_col.NumContacts() != 0){
        target_cam_distance = distance(cam_pos, sphere_col.position);
    }
    
    if(shared_cam){
        // Set camera to minimum distance that keeps characters on the screen
        if(num_players == 2){
            MovementObject @char_a = ReadCharacterID(player_ids[0]);
            MovementObject @char_b = ReadCharacterID(player_ids[1]);
            target_cam_distance = length(char_b.position - char_a.position) * 0.5f + kCamFollowDistance;
        } else {
            float max_dist = 0.0f;
            for(int i=0; i<num_players-1; ++i){
                for(int j=i+1; j<num_players; ++j){
                    MovementObject @char_a = ReadCharacterID(player_ids[i]);
                    MovementObject @char_b = ReadCharacterID(player_ids[j]);
                    max_dist = max(max_dist, length(char_b.position - char_a.position));
                }
            }
            target_cam_distance = max(2.0f, max_dist - 1.5f);
        }
    }

    // Snap in to target distance or ease out to target distance
    cam_distance = min(cam_distance, target_cam_distance);
    cam_distance = mix(target_cam_distance, cam_distance, 0.95f);
        
    // If this is the first frame, set camera to match character facing
    if(!cam_rotation_set && !shared_cam){        
        vec3 facing = this_mo.GetFacing();
        float cur_rotation = atan2(-facing.x, -facing.z)/(3.1415f/180.0f);
        cam_rotation = cur_rotation;
        target_rotation = cam_rotation;
        cam_rotation2 = -20.0f;
        target_rotation2 = cam_rotation2;
        cam_rotation_set = true;
    }

    // Apply camera state to actual scene camera
    camera.SetYRotation(cam_rotation);    
    camera.SetXRotation(cam_rotation2);  
    camera.SetZRotation(0.0f);
    camera.SetFOV(90);
    camera.SetPos(cam_pos);
    camera.CalcFacing();
    camera.SetDistance(cam_distance);
    if(this_mo.controller_id == 0){
        UpdateListener(camera.GetPos(),vec3(0,0,0),camera.GetFacing(),camera.GetUpVector());
    }
    camera.SetInterpSteps(ts.frames());

    // Record 'old' state
    if(state == _ragdoll_state){
        ragdoll_cam_pos = cam_pos;
    }
    old_cam_pos = cam_pos;
}

void ApplyCameraCones(vec3 cam_pos){
    bool debug_viz = false;
    float radius = 0.8f;
    if(debug_viz){
        DebugDrawWireSphere(cam_pos, radius, vec3(1.0f,0.0f,0.0f), _delete_on_update);
    }
    col.GetSlidingSphereCollision(cam_pos, radius);
    vec3 offset = sphere_col.adjusted_position - cam_pos;
    vec3 bad_dir = normalize(offset*-1.0f);
    if(debug_viz){
        DebugDrawLine(cam_pos,
                      cam_pos + bad_dir * radius,
                      vec3(1.0f),
                      _delete_on_update);
    }
    float penetration = 1.0f-length(offset)/radius;

    if(debug_viz){
        float penetration_angle = acos(penetration);
        vec3 b_up(0.0f,1.0f,0.0f);
        if(abs(dot(b_up, bad_dir))>0.9f){
            b_up = vec3(1.0f,1.0f,1.0f);
        }
        vec3 b_right = normalize(cross(bad_dir, b_up));
        b_up = normalize(cross(bad_dir, b_right));
        DebugDrawLine(cam_pos,
                      cam_pos + bad_dir * penetration + b_right * sin(penetration_angle),
                      vec3(1.0f),
                      _delete_on_update);
        DebugDrawLine(cam_pos,
                      cam_pos + bad_dir * penetration - b_right * sin(penetration_angle),
                      vec3(1.0f),
                      _delete_on_update);
        DebugDrawLine(cam_pos,
                      cam_pos + bad_dir * penetration + b_up * sin(penetration_angle),
                      vec3(1.0f),
                      _delete_on_update);
        DebugDrawLine(cam_pos,
                      cam_pos + bad_dir * penetration - b_up * sin(penetration_angle),
                      vec3(1.0f),
                      _delete_on_update);
    }

    

    mat4 rotationY_mat,rotationX_mat;
    rotationY_mat.SetRotationY(target_rotation*3.1415f/180.0f);
    rotationX_mat.SetRotationX(target_rotation2*3.1415f/180.0f);
    mat4 rotation_mat = rotationY_mat * rotationX_mat;
    vec3 facing = rotation_mat * vec3(0.0f,0.0f,-1.0f);

    penetration -= 0.3f;
    penetration = max(-0.2f, penetration);

    if(dot(facing, bad_dir * -1.0f) > penetration){ 
        float old_target_rotation = target_rotation;
        vec3 new_right = normalize(cross(normalize(cross(bad_dir,facing)),bad_dir)); 

        if(facing == bad_dir){
            facing += vec3(0.1f,0.1f,0.1f);
        }

        vec3 rot_facing;
        rot_facing.x = dot(facing, bad_dir)*-1.0f ;
        rot_facing.y = dot(facing, new_right);
        bool neg = rot_facing.y < 0;

        rot_facing.x = penetration;
        rot_facing.y = sqrt(1.0f - penetration * penetration);
        if(neg){
            rot_facing.y *= -1.0f;
        }

        facing = bad_dir * rot_facing.x * -1.0f + new_right * rot_facing.y;
        target_rotation2 = asin(facing.y)/3.14159265f * 180.0f;
        facing.y = 0.0f;
        facing = normalize(facing);
        target_rotation = atan2(-facing.x,-facing.z)/3.14159265f * 180.0f;
        while(target_rotation > old_target_rotation + 180.0f){
            target_rotation -= 360.0f;
        }
        while(target_rotation < old_target_rotation - 180.0f){
            target_rotation += 360.0f;
        }
    }

}


bool NeedsCombatPose() {
    if(startled){
        return false;
    }

    const float _combat_pose_dist_threshold = 5.0f;
    const float _combat_pose_dist_threshold_2 =  _combat_pose_dist_threshold * _combat_pose_dist_threshold;

    for(uint i=0; i<situation.known_chars.size(); ++i){
        if(!situation.known_chars[i].friendly && 
            situation.known_chars[i].knocked_out == _awake && 
            situation.known_chars[i].last_seen_time > time - 1.0f)
        {
            MovementObject@ char = ReadCharacterID(situation.known_chars[i].id);
            if((char.GetIntVar("knocked_out") == _awake) &&
               distance_squared(char.position, this_mo.position) < _combat_pose_dist_threshold_2  && 
               char.QueryIntFunction("int IsUnaware()")!=1)
            {
                return true;
            }
        }
    }

    return false;
}

void ResetLayers() {
    active_block_flinch_layer = -1;
    sheathe_layer_id = -1;
    ragdoll_layer_catchfallfront = -1;
    ragdoll_layer_fetal = -1;
    knife_layer_id = -1;
    throw_knife_layer_id = -1;
    pickup_layer = -1;
}

void SwitchCharacter(string path){
    DropWeapon();
    this_mo.DetachAllItems();
    this_mo.char_path = path;
    character_getter.Load(this_mo.char_path);
    this_mo.RecreateRiggedObject(this_mo.char_path);
    ResetLayers();
    ResetSecondaryAnimation();
    CacheSkeletonInfo();
    ApplyIdle(5.0f, true);
    SetState(_movement_state);
    Recover();
    RandomizeColors();
}

void Init(string character_path) {
    StartFootStance();
    this_mo.char_path = character_path;
    character_getter.Load(this_mo.char_path);
    this_mo.RecreateRiggedObject(this_mo.char_path);
    ResetLayers();
    for(int i=0; i<5; ++i){
        HandleBumperCollision();
        HandleStandingCollision();
        this_mo.position = sphere_col.position;
        last_col_pos = this_mo.position;
    }
    SetState(_movement_state);
    PostReset();
}

void ScriptSwap() {
    last_col_pos = this_mo.position;
}

void Reset() {
    this_mo.rigged_object().anim_client().RemoveAllLayers();
    ResetLayers();
    StartFootStance();
    DropWeapon(); 
    this_mo.ResetSoftAnimation();
    this_mo.DetachAllItems();
    if(state == _ragdoll_state){
        this_mo.UnRagdoll();
        ApplyIdle(5.0f,true);
        ragdoll_cam_recover_speed = 1000.0f;
        ragdoll_fade_speed = 1000.0f;
    }
    tilt_modifier = vec3(0.0f,1.0f,0.0f);
    flip_modifier_rotation = 0.0f;
    this_mo.rigged_object().CleanBlood();
    ClearTemporaryDecals();
    blood_amount = _max_blood_amount;
    ResetMind();
    reset_no_collide = the_time;
    SetTetherID(-1);
}

void PostReset() {
    CacheSkeletonInfo();
    weapon_slots.resize(_num_weap_slots);
    for(int i=0; i<_num_weap_slots; ++i){
        weapon_slots[i] = -1;       
    }
    if(body_bob_freq == 0.0f){
        body_bob_freq = RangedRandomFloat(0.9f,1.1f);
        body_bob_time_offset = RangedRandomFloat(0.0f,100.0f);
    }
}

void StartFootStance() {
    foot.resize(2);
    foot[0].planted = true;
    foot[1].planted = false;
    for(int i=0; i<2; ++i){
         foot[i].pos = vec3(0.0f);
         foot[i].target_pos = this_mo.position;
         foot[i].old_pos = this_mo.position;
         foot[i].height = 0.0f;
         foot[i].progress = 0.0f;
    }
}

void HandleFootStance(const Timestep &in ts) {
    use_foot_plants = true;
    if(!old_use_foot_plants){
        StartFootStance();
    }

    vec3 temp_vel = this_mo.velocity + push_velocity;
    const float step_speed = max(2.0f,length(temp_vel)*1.5f + 1.0f);

    for(int i=0; i<2; ++i){
        foot[i].target_pos = this_mo.position;
    }
    vec3 diff = this_mo.rigged_object().GetIKTargetAnimPosition("right_leg") -
                this_mo.rigged_object().GetIKTargetAnimPosition("left_leg");
    if(length_squared(temp_vel) > 0.001f){
        vec3 n_diff = normalize(diff);
        vec3 n_vel = normalize(temp_vel);
        float val = dot(n_diff, n_vel);
        foot[0].target_pos += temp_vel * time_step * 1.0f * (-val+1.0f);
        foot[1].target_pos += temp_vel * time_step * 1.0f * (val+1.0f);
        for(int i=0; i<2; ++i){
            foot[i].target_pos += temp_vel * time_step * 60.0f / step_speed;
        }
    }
    if(foot[0].planted && foot[1].planted &&
        (distance_squared(foot[1].target_pos, foot[1].old_pos) > 0.01f ||
         distance_squared(foot[0].target_pos, foot[0].old_pos) > 0.01f))
    {
        if(dot(diff, temp_vel) > 0.0f){
            foot[1].planted = false;
        } else {
            foot[0].planted = false;
        }
    }

    for(int i=0; i<2; ++i){
        if(!foot[i].planted){
            foot[i].progress += ts.step() * step_speed;
            foot[i].height = min(0.1f,sin(foot[i].progress * 3.1415f) * length_squared(temp_vel)*0.005f);
        }
        if(foot[i].progress >= 1.0f){
            foot[i].old_pos = foot[i].target_pos;
            foot[i].progress = 0.0f;
            foot[i].planted = true;
            if(distance_squared(foot[1-i].target_pos, foot[1-i].old_pos) > 0.01f){
                foot[1-i].planted = false;
            }
            foot[i].height = 0.0f;
            string event_name;
            vec3 event_pos;
            if(i==0){
                event_pos = this_mo.rigged_object().GetIKTargetPosition("left_leg");
                event_name += "left";
            } else {
                event_pos = this_mo.rigged_object().GetIKTargetPosition("right_leg");
                event_name += "right";
            }
            if(length_squared(temp_vel) < 4.0f){
                event_name += "crouchwalk";
            } else if(length_squared(temp_vel) < 20.0f){
                event_name += "walk";
            } else {
                event_name += "run";
            }
            event_name += "step";

            HandleAnimationMaterialEvent(event_name, event_pos);
        }
        foot[i].pos = mix(foot[i].old_pos, foot[i].target_pos, foot[i].progress);
        foot[i].pos -= this_mo.position;
    }
}

void UpdateAnimation(const Timestep &in ts) {
    vec3 flat_velocity = vec3(this_mo.velocity.x,0,this_mo.velocity.z);

    float run_amount, walk_amount, idle_amount;
    float speed = length(flat_velocity);
    
    /*if(this_mo.controlled){
        DebugText("a","Tall coord: "+(1.0f-duck_amount), 0.5f);
        DebugText("b","Threat coord: "+max(0.0f,threat_amount-0.01f), 0.5f);
    }*/
    this_mo.rigged_object().anim_client().SetBlendCoord("tall_coord",1.0f-duck_amount);
    this_mo.rigged_object().anim_client().SetBlendCoord("threat_coord",threat_amount);
    idle_stance = false;

    if(flip_info.IsFlipping()){
        flip_ik_fade = min(flip_ik_fade + 5.0f * ts.step(), 1.1f);
    } else {
        flip_ik_fade = max(flip_ik_fade - 3.0f * ts.step(), 0.0f);
    }

    if(on_ground){
        // rolling on the ground
        if(flip_info.UseRollAnimation()){
            int8 flags = 0;
            if(!mirrored_stance){
                flags |= _ANM_MIRRORED;
            }
            this_mo.SetCharAnimation("roll",4.0f,flags);
            float forwards_rollness = 1.0f-abs(dot(flip_info.GetAxis(),this_mo.GetFacing()));
            this_mo.rigged_object().anim_client().SetBlendCoord("forward_roll_coord",forwards_rollness);
            this_mo.rigged_object().ik_enabled = false;
            roll_ik_fade = min(roll_ik_fade + 5.0f * ts.step(), 1.0f);
        } else {
            // running, walking and idle animation
            this_mo.rigged_object().ik_enabled = true;
            
            // when he's moving instead of idling, the character turns to the movement direction.
            // the different movement types are listed in XML files, and are blended together
            // by variables such as speed or crouching amount (blending values should be 0 and 1)
            // when there are more than two animations to blend, the XML file refers to another 
            // XML file which asks for another blending variable.
            stance_move = false;
            int force_look_target = IsAware()?situation.GetForceLookTarget():-1;
            if(force_look_target != -1 && speed < _stance_move_threshold && trying_to_get_weapon == 0){
                if(NeedsCombatPose())
                {
                    stance_move = true;
                    stance_move_fade = 1.0f;
                }
            }
            if(tethered != _TETHERED_FREE){
                stance_move = true;

            }
            if((speed < _walk_threshold && GetTargetVelocity() != vec3(0.0f)) || 
                knife_layer_id != -1 || 
                throw_knife_layer_id != -1 && (speed < _walk_threshold * 2.0f))
            {
                stance_move = true;
            }
            WalkDir walk_dir = WantsToWalkBackwards();
            if(walk_dir != FORWARDS && length_squared(flat_velocity) > 0.001f){
                stance_move = true;
                if(walk_dir == WALK_BACKWARDS){
                    this_mo.SetRotationFromFacing(InterpDirections(this_mo.GetFacing(),
                                                                   normalize(flat_velocity * -1.0f),
                                                                   1.0 - pow(0.95f, ts.frames())));
                }
            }

            if(speed > _walk_threshold && feet_moving && !stance_move){
                vec3 facing = this_mo.GetFacing();
                float angle = -atan2(-facing.z, facing.x);

                vec3 target_look = normalize(GetTargetVelocity() + normalize(flat_velocity) * 0.1f);
                float target_look_angle = -atan2(-target_look.z, target_look.x);

                if(target_look_angle > angle + 3.1417f){
                    target_look_angle -= 3.1417f*2.0f;
                } else if(target_look_angle < angle - 3.1417f){
                    target_look_angle += 3.1417f*2.0f;
                }

                float look_max = 3.1417f*0.6f;
                if(abs(angle - target_look_angle) < look_max){
                    target_look_angle = target_look_angle;
                } else if(angle < target_look_angle){
                    target_look_angle = angle + look_max;
                } else if(angle > target_look_angle){
                    target_look_angle = angle - look_max;
                }

                vec3 target_facing = normalize(flat_velocity);
                float target_angle = -atan2(-target_facing.z, target_facing.x);
                if(dot(this_mo.GetFacing(), target_look) < 0.0f){
                    target_angle = target_look_angle;
                }

                if(target_angle > angle + 3.1417f){
                    target_angle -= 3.1417f*2.0f;
                } else if(target_angle < angle - 3.1417f){
                    target_angle += 3.1417f*2.0f;
                }

                float turn_speed = ts.step() * 10.0f;

                if(abs(angle - target_angle) < turn_speed){
                    angle = target_angle;
                } else if(angle < target_angle){
                    angle += turn_speed;
                } else if(angle > target_angle){
                    angle -= turn_speed;
                }
       
                run_eye_look_target = this_mo.position + vec3(cos(target_look_angle), 0.0f, sin(target_look_angle)) * 100.0f;

                vec3 new_facing(cos(angle), 0.0f, sin(angle));
                this_mo.SetRotationFromFacing(new_facing);
                /*this_mo.SetRotationFromFacing(InterpDirections(this_mo.GetFacing(),
                                                               normalize(flat_velocity),
                                                               1.0 - pow(0.8f, ts.frames())));
                */
                int8 flags = 0;
                if(left_handed){
                    flags |= _ANM_MIRRORED;
                }
                this_mo.SetCharAnimation("movement", 5.0f, flags);
                this_mo.rigged_object().anim_client().SetBlendCoord("speed_coord",speed/this_mo.rigged_object().GetCharScale());
                this_mo.rigged_object().anim_client().SetBlendCoord("ground_speed",speed/this_mo.rigged_object().GetCharScale());
                this_mo.rigged_object().anim_client().SetAnimatedItemID(0, weapon_slots[primary_weapon_slot]);
                mirrored_stance = left_handed;
            } else {
                if(stance_move){
                    if(throw_knife_layer_id != -1 && force_look_target == -1){
                        force_look_target = target_id;
                    }
                    if(force_look_target != -1 && (speed > 1.0f || knife_layer_id != -1 || throw_knife_layer_id != -1) && tethered == _TETHERED_FREE){
                        MovementObject@ char = ReadCharacterID(force_look_target);
                        vec3 dir = char.position - this_mo.position;
                        dir.y = 0.0f;
                        dir = normalize(dir);
                        this_mo.SetRotationFromFacing(
                            InterpDirections(this_mo.GetFacing(), dir, 1.0 - pow(0.9f, ts.frames())));
                    } 
                    HandleFootStance(ts);
                }
                if(tethered == _TETHERED_FREE){
                    idle_stance = true;
                    ApplyIdle(5.0f, false);
                } else {
                    int8 flags = _ANM_MOBILE;
                    if(mirrored_stance){
                        flags = flags | _ANM_MIRRORED;
                    }
                    if(tethered == _TETHERED_REARCHOKE && !executing){
                        if(weapon_slots[primary_weapon_slot] == -1){
                            this_mo.SetAnimation("Data/Animations/r_rearchokestance.xml", 5.0f, flags);
                        } else {
                            this_mo.SetAnimation("Data/Animations/r_rearknifecapturestance.xml", 5.0f, flags);
                        }
                    } else if(tethered == _TETHERED_REARCHOKED){
                        MovementObject@ char = ReadCharacterID(tether_id);
                        int weap_id = GetCharPrimaryWeapon(char);
                        if(weap_id == -1){
                            this_mo.SetAnimation("Data/Animations/r_rearchokedstance.xml", 5.0f, flags);
                        } else {
                            if(being_executed != STARTING_THROAT_CUT){
                                this_mo.SetAnimation("Data/Animations/r_rearknifecapturedstance.xml", 5.0f, flags);
                            } else {
                                this_mo.SetAnimation("Data/Animations/r_throatcuttee.anm", 10.0f, flags);
                            }
                        }
                    } else if(tethered == _TETHERED_DRAGBODY){
                        if(weapon_slots[_held_right] == -1 && weapon_slots[_held_left] == -1){
                            this_mo.SetAnimation("Data/Animations/r_dragstance.xml", 3.0f, flags);
                        } else {
                            flags = 0;
                            mirrored_stance = false;
                            if(weapon_slots[_held_right] == -1){
                                flags |= _ANM_MIRRORED;
                                mirrored_stance = true;
                            }
                            this_mo.SetAnimation("Data/Animations/r_dragstanceone.xml", 3.0f, flags);
                        }
                    }
                    this_mo.rigged_object().anim_client().SetAnimatedItemID(0, weapon_slots[primary_weapon_slot]);
                }
                this_mo.rigged_object().ik_enabled = true;
            }
            roll_ik_fade = max(roll_ik_fade - 5.0f * ts.step(), 0.0f);
        }
    } else {
        jump_info.UpdateAirAnimation();
    }

    if(idle_stance){
        idle_stance_amount = mix(1.0f, idle_stance_amount, pow(0.94f, ts.frames()));
    } else {
        idle_stance_amount = mix(0.0f, idle_stance_amount, pow(0.98f, ts.frames()));
    }

    old_use_foot_plants = use_foot_plants;
}
    
vec3 GetLegTargetOffset(vec3 initial_pos, vec3 anim_pos){
    /*DebugDrawLine(initial_pos + vec3(0.0f,_check_up,0.0f),
                  initial_pos + vec3(0.0f,_check_down,0.0f),
                  vec3(1.0f),
                  _delete_on_draw);*/
    col.GetSweptSphereCollision(initial_pos + vec3(0.0f,_check_up,0.0f),
                                    initial_pos + vec3(0.0f,_check_down,0.0f),
                                    0.05f);

    if(sphere_col.NumContacts() == 0){
        return vec3(0.0f);
    }

    float target_y_pos = sphere_col.position.y;
    float height = anim_pos.y + _leg_sphere_size + 0.2f;
    target_y_pos += height;
    /*DebugDrawWireSphere(initial_pos,
                  0.05f,
                  vec3(1.0f,0.0f,0.0f),
                  _delete_on_draw);
    DebugDrawWireSphere(sphere_col.position,
                  0.05f,
                  vec3(0.0f,1.0f,0.0f),
                  _delete_on_draw);*/

    float offset_amount = target_y_pos - initial_pos.y;
    offset_amount /= max(0.0f,height)+1.0f;

    offset_amount = max(-0.15f,min(0.15f,offset_amount));

    return vec3(0.0f,offset_amount,0.0f);
}

vec3 GetLimbTargetOffset(vec3 initial_pos, vec3 anim_pos){
    /*DebugDrawLine(initial_pos + vec3(0.0f,0.0f,0.0f),
                  initial_pos + vec3(0.0f,_check_down,0.0f),
                  vec3(1.0f),
                  _delete_on_draw);
    */
    col.GetSweptSphereCollision(initial_pos + vec3(0.0f,_check_up,0.0f),
                                    initial_pos + vec3(0.0f,_check_down,0.0f),
                                    0.05f);

    if(sphere_col.NumContacts() == 0){
        return vec3(0.0f);
    }

    float target_y_pos = sphere_col.position.y;
    float height = anim_pos.y + 0.8f;// _leg_sphere_size;
    target_y_pos += height;
    /*DebugDrawWireSphere(sphere_col.position,
                  0.05f,
                  vec3(1.0f),
                  _delete_on_draw);
    */
    float offset_amount = target_y_pos - initial_pos.y;
    //offset_amount /= max(0.0f,height)+1.0f;

    offset_amount = max(-0.3f,min(0.3f,offset_amount));

    return vec3(0.0,offset_amount, 0.0f);
}

void SetLimbTargetOffset(string name){
    vec3 pos = this_mo.rigged_object().GetIKTargetPosition(name);
    vec3 anim_pos = this_mo.rigged_object().GetIKTargetAnimPosition(name);
    vec3 offset = GetLimbTargetOffset(pos, anim_pos);
    this_mo.rigged_object().SetIKTargetOffset(name,offset+vec3(0.0f,-0.15f,0.0f));
}

array<int> debug_lines;

vec3 GetRagdollPoseCenterOfMass(){
    RiggedObject@ rigged_object = this_mo.rigged_object();
    Skeleton@ skeleton = rigged_object.skeleton();
    int num_bones = skeleton.NumBones();
    vec3 com;
    float total_mass = 0.0f;
    for(int i=0; i<num_bones; ++i){
        mat4 transform = ragdoll_pose[i];
        float bone_mass = skeleton.GetBoneMass(i);
        com += transform.GetTranslationPart() * bone_mass;
        total_mass += bone_mass;
    }
    if(total_mass != 0.0f){
        com /= total_mass;
    }
    return com;
}

mat4 GetFrameAverageMatrix() {
    RiggedObject@ rigged_object = this_mo.rigged_object();
    Skeleton@ skeleton = rigged_object.skeleton();
    int num_bones = skeleton.NumBones();
    mat4 total_transform;
    float total_mass = 0.0f;
    for(int i=0; i<num_bones; ++i){
        float bone_mass = skeleton.GetBoneMass(i);
        mat4 transform = rigged_object.GetFrameMatrix(i).GetMat4();
        for(int j=0; j<16; ++j){
            total_transform[j] += bone_mass * transform[j];
        }
        total_mass += bone_mass;
    }
    if(total_mass != 0.0f){
        for(int i=0; i<16; ++i){
            total_transform[i] /= total_mass;
        }
    }
    return total_transform;
}


mat4 GetFrameAverageDeltaMatrix() {
    RiggedObject@ rigged_object = this_mo.rigged_object();
    Skeleton@ skeleton = rigged_object.skeleton();
    int num_bones = skeleton.NumBones();
    mat4 total_transform;
    float total_mass = 0.0f;
    for(int i=0; i<num_bones; ++i){
        float bone_mass = skeleton.GetBoneMass(i);
        mat4 transform = (rigged_object.GetFrameMatrix(i) * inv_skeleton_bind_transforms[i]).GetMat4();
        for(int j=0; j<16; ++j){
            total_transform[j] += bone_mass * transform[j];
        }
        total_mass += bone_mass;
    }
    if(total_mass != 0.0f){
        for(int i=0; i<16; ++i){
            total_transform[i] /= total_mass;
        }
    }
    return total_transform;
}

void RotateBonesToMatchVec(vec3 a, vec3 c, int bone, int bone2, float weight) {
    vec3 b = mix(a,c,1.0f-weight);

    BoneTransform mat = this_mo.rigged_object().GetFrameMatrix(bone);
    mat.origin = (a+b)*0.5f;
    quaternion rot = mat.rotation;
    vec3 dir = rot * vec3(0,0,1);
    GetRotationBetweenVectors(dir, b - a, rot);
    mat.rotation = rot * mat.rotation;
    this_mo.rigged_object().SetFrameMatrix(bone, mat);

    mat = this_mo.rigged_object().GetFrameMatrix(bone2);
    mat.origin = (b+c)*0.5f;
    mat.rotation = rot * mat.rotation;
    this_mo.rigged_object().SetFrameMatrix(bone2, mat);
}

void DrawLeg(bool right, const BoneTransform &in hip_transform, const BoneTransform &in foot_transform, int num_frames) {
    EnterTelemetryZone("DrawLeg");
    RiggedObject@ rigged_object = this_mo.rigged_object();
    Skeleton@ skeleton = rigged_object.skeleton();

    int ik_chain_start = ik_chain_start_index[kLeftLegIK+(right?1:0)];

    // Get important joint positions
    vec3 foot_tip, foot_base, ankle, knee, hip;
    foot_tip = rigged_object.GetTransformedBonePoint(ik_chain_elements[ik_chain_start+0], 1);
    foot_base = rigged_object.GetTransformedBonePoint(ik_chain_elements[ik_chain_start+0], 0);
    ankle = rigged_object.GetTransformedBonePoint(ik_chain_elements[ik_chain_start+1], 0);
    knee = rigged_object.GetTransformedBonePoint(ik_chain_elements[ik_chain_start+3], 0);
    hip = rigged_object.GetTransformedBonePoint(ik_chain_elements[ik_chain_start+5], 0);

    vec3 old_foot_dir = foot_tip - foot_base;
    float upper_foot_length = ik_chain_bone_lengths[ik_chain_start+1];
    float lower_leg_length = (ik_chain_bone_lengths[ik_chain_start+2]+ik_chain_bone_lengths[ik_chain_start+3]);
    float upper_leg_length = (ik_chain_bone_lengths[ik_chain_start+4]+ik_chain_bone_lengths[ik_chain_start+5]);
    
    float lower_leg_weight = ik_chain_bone_lengths[ik_chain_start+2] / lower_leg_length;
    float upper_leg_weight = ik_chain_bone_lengths[ik_chain_start+4] / upper_leg_length;

    vec3 old_hip = hip;
    float old_length = distance(foot_base, old_hip);
    
    // New hip position based on key hip transform
    hip = hip_transform * skeleton.GetPointPos(skeleton.GetBonePoint(ik_chain_elements[ik_chain_start+5], 0));

    // New foot_base position based on key foot transform
    vec3 ik_target = foot_transform * skeleton.GetPointPos(skeleton.GetBonePoint(ik_chain_elements[ik_chain_start+0], 0));
    
    quaternion rotate;
    GetRotationBetweenVectors(foot_base - old_hip, ik_target - hip, rotate);
    mat3 rotate_mat = Mat3FromQuaternion(rotate);
    knee = rotate_mat * (knee-old_hip)+hip;
    ankle = rotate_mat * (ankle-old_hip)+hip;
    foot_base = rotate_mat * (foot_base-old_hip)+hip;
    float new_length = distance(ik_target, hip);
    float weight = new_length / old_length;
    knee = mix(hip, knee, weight);
    ankle = mix(hip, ankle, weight);
    foot_base = mix(hip, foot_base, weight);
    foot_tip = foot_transform * skeleton.GetPointPos(skeleton.GetBonePoint(ik_chain_elements[ik_chain_start+0], 1));
    
    int num_iterations = 2;
    for(int i=0; i<num_iterations; ++i){
        knee = hip + normalize(knee - hip) * upper_leg_length;
        ankle = foot_base + normalize(ankle - foot_base) * upper_foot_length;
        vec3 knee_ankle_vec = normalize(knee - ankle);
        vec3 mid = (knee + ankle) * 0.5f;
        ankle = mid - knee_ankle_vec * 0.5f * lower_leg_length;
        knee = mid + knee_ankle_vec * 0.5f * lower_leg_length;
    }
    if(draw_skeleton_lines){
        debug_lines.push_back(DebugDrawLine(foot_tip, foot_base, vec3(1.0f), _fade));
        debug_lines.push_back(DebugDrawLine(foot_base, ankle, vec3(1.0f), _fade));
        debug_lines.push_back(DebugDrawLine(ankle, knee, vec3(1.0f), _fade));
        debug_lines.push_back(DebugDrawLine(knee, hip, vec3(1.0f), _fade));
    }

    rigged_object.SetFrameMatrix(ik_chain_elements[ik_chain_start+0], foot_transform * inv_skeleton_bind_transforms[ik_chain_elements[ik_chain_start+0]]);

    rigged_object.RotateBoneToMatchVec(foot_base, foot_tip, ik_chain_elements[ik_chain_start+0]);
    rigged_object.RotateBoneToMatchVec(ankle, foot_base, ik_chain_elements[ik_chain_start+1]);
    rigged_object.RotateBonesToMatchVec(knee, ankle, ik_chain_elements[ik_chain_start+3], ik_chain_elements[ik_chain_start+2], lower_leg_weight);
    rigged_object.RotateBonesToMatchVec(hip, knee, ik_chain_elements[ik_chain_start+5], ik_chain_elements[ik_chain_start+4], upper_leg_weight);
    LeaveTelemetryZone();
}

int GetNumBoneChildren(int bone){
    return bone_children_index[bone+1] - bone_children_index[bone];
}

int GetBoneChild(int bone, int which_child){
    return bone_children[bone_children_index[bone]+which_child];
}

array<vec3> temp_old_weap_points;
array<vec3> old_weap_points;
array<vec3> weap_points;
void DrawWeapon(int num_frames, quaternion &out weap_rotation, vec3 &out weap_old_mid, vec3 &out weap_new_mid) {
    int primary_weapon_id = weapon_slots[primary_weapon_slot];
    if(primary_weapon_id != -1){
        ItemObject@ item_obj = ReadItemID(primary_weapon_id);
        int num_lines = item_obj.GetNumLines();
        if(num_lines > 0){
            mat4 transform = item_obj.GetPhysicsTransform();
            vec3 start = transform * item_obj.GetLineStart(0);
            vec3 end = transform * item_obj.GetLineEnd(num_lines-1);
            //debug_lines.push_back(DebugDrawLine(start, end, vec3(1.0f), _fade));
            if(old_weap_points.size() == 0){
                temp_old_weap_points.resize(2);
                old_weap_points.resize(2);
                weap_points.resize(2);  
                weap_points[0] = start;
                weap_points[1] = end;
                for(int i=0; i<2; ++i){
                    old_weap_points[i] = weap_points[i];
                    temp_old_weap_points[i] = weap_points[i];
                }              
            }
            for(int i=0; i<2; ++i){
                temp_old_weap_points[i] = weap_points[i];
            }
            for(int i=0; i<2; ++i){
                weap_points[i] += (weap_points[i] - old_weap_points[i]) * 0.9f;
            }
            weap_points[0] = mix(start, weap_points[0], 0.99f);
            weap_points[1] = mix(end, weap_points[1], 0.99f);
            weap_new_mid = (weap_points[0] + weap_points[1])*0.5f;
            vec3 dir = normalize(weap_points[1] - weap_points[0]);
            float weap_length = distance(start,end);
            weap_points[0] = weap_new_mid - weap_length*dir*0.5f;
            weap_points[1] = weap_new_mid + weap_length*dir*0.5f;
            weap_old_mid = (start+end)*0.5f;
            GetRotationBetweenVectors(end-start, dir, weap_rotation);
            debug_lines.push_back(DebugDrawLine(weap_points[0], weap_points[1], vec3(1.0f), _fade));
            for(int i=0; i<2; ++i){
                old_weap_points[i] = temp_old_weap_points[i];
            }
        }
    }
}

// Verlet integration for arm physics
array<vec3> temp_old_arm_points;
array<vec3> old_arm_points;
array<vec3> arm_points;
enum ChainPointLabels {kHandPoint, kWristPoint, kElbowPoint, kShoulderPoint, kCollarTipPoint, kCollarPoint, kNumArmPoints};

vec3 GetChainPoint(int chain_element, int bone_end){
    RiggedObject@ rigged_object = this_mo.rigged_object();
    Skeleton@ skeleton = rigged_object.skeleton();
    return skeleton.GetPointPos(skeleton.GetBonePoint(ik_chain_elements[chain_element], bone_end));
}

void DrawArms(const BoneTransform &in chest_transform, const BoneTransform &in l_hand_transform, const BoneTransform &in r_hand_transform, int num_frames){
    EnterTelemetryZone("DrawArms");
    RiggedObject@ rigged_object = this_mo.rigged_object();
    Skeleton@ skeleton = rigged_object.skeleton();

    // Get relative chest transformation
    int chest_bone = skeleton.IKBoneStart("torso");
    BoneTransform chest_frame_matrix = rigged_object.GetFrameMatrix(chest_bone);
    BoneTransform chest_bind_matrix = skeleton_bind_transforms[chest_bone];
    BoneTransform rel_mat = chest_transform * invert(chest_frame_matrix * chest_bind_matrix);

    // Get points in arm IK chain transformed by chest
    array<float> upper_arm_length;
    array<float> upper_arm_weight;
    array<float> lower_arm_length;
    array<float> lower_arm_weight;
    array<vec3> chain_points;
    chain_points.resize(kNumArmPoints * 2);
    upper_arm_length.resize(2);
    upper_arm_weight.resize(2);
    lower_arm_length.resize(2);
    lower_arm_weight.resize(2);

    //BoneTransform left_hand = l_hand_transform * inv_skeleton_bind_transforms[ik_chain_elements[ik_chain_start_index[kLeftArmIK]]];
    //BoneTransform right_hand = r_hand_transform * inv_skeleton_bind_transforms[ik_chain_elements[ik_chain_start_index[kRightArmIK]]];

    //DebugDrawWireSphere(right_hand.origin, 0.1f, vec3(1.0f), _fade);
    //DebugDrawWireSphere(left_hand.origin, 0.1f, vec3(1.0f), _fade);
    //DebugDrawLine(left_hand.origin, right_hand.origin, vec3(1.0f), _fade);

    for(int right=0; right<2; ++right){
        int chain_start = ik_chain_start_index[kLeftArmIK+right];
        vec3 hand = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+0], 1);
        vec3 wrist = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+0], 0);
        vec3 elbow = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+2], 0);
        vec3 shoulder = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+4], 0);
        vec3 collar_tip = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+5], 1);
        vec3 collar = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+5], 0);

        // Get more metrics about arm lengths
        upper_arm_length[right] = distance(elbow, shoulder);
        lower_arm_length[right] = distance(wrist, elbow);
        
        vec3 mid_low_arm = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+1], 0);
        vec3 mid_up_arm = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+3], 0);

        lower_arm_weight[right] = distance(elbow, mid_low_arm) / distance(wrist, elbow);
        upper_arm_weight[right] = distance(shoulder, mid_up_arm) / distance(shoulder, elbow);


        BoneTransform world_chest = key_transforms[kChestKey] * inv_skeleton_bind_transforms[ik_chain_start_index[kTorsoIK]];
        vec3 breathe_dir = world_chest.rotation * normalize(vec3(0,-0.3,1));
        float scale = this_mo.rigged_object().GetCharScale();
        shoulder += breathe_dir * breath_amount *  0.005f * scale;

        { // Apply traditional IK
            vec3 old_wrist = wrist;
            vec3 old_shoulder = shoulder;
            BoneTransform hand_transform = right==1?r_hand_transform:l_hand_transform;
        
            hand = hand_transform * GetChainPoint(chain_start+0, 1);
            wrist = hand_transform * GetChainPoint(chain_start+0, 0);
            shoulder = rel_mat * shoulder;

            // Rotate arm to match new IK pos
            quaternion rotation;
            GetRotationBetweenVectors(old_wrist - old_shoulder, wrist - shoulder, rotation);
            elbow = shoulder + Mult(rotation, elbow-old_shoulder);

            // Scale to put elbow in approximately the right place
            float old_length = distance(old_wrist, old_shoulder);
            float new_length = distance(wrist, shoulder);
            elbow = shoulder + (elbow - shoulder) * (new_length / old_length);

            // Enforce arm lengths to finalize elbow position
            const int iterations = 2;
            for(int i=0; i<iterations; ++i){
                vec3 offset;
                offset += (shoulder + normalize(elbow-shoulder) * upper_arm_length[right]) - elbow;
                offset += (wrist + normalize(elbow-wrist) * lower_arm_length[right]) - elbow;
                elbow += offset;
            }
        }

        collar_tip = rel_mat * collar_tip;
        collar = rel_mat * collar;

        int points_offset = kNumArmPoints * right;
        chain_points[kHandPoint+points_offset] = hand;
        chain_points[kWristPoint+points_offset] = wrist;
        chain_points[kElbowPoint+points_offset] = elbow;
        chain_points[kShoulderPoint+points_offset] = shoulder;
        chain_points[kCollarTipPoint+points_offset] = collar_tip;
        chain_points[kCollarPoint+points_offset] = collar;
    }

    old_arm_points.resize(6);
    temp_old_arm_points.resize(6);
    if(arm_points.size()!=6){ // Initialize arm physics particles
        arm_points.push_back(chain_points[kShoulderPoint]);
        arm_points.push_back(chain_points[kElbowPoint]);
        arm_points.push_back(chain_points[kWristPoint]);
        arm_points.push_back(chain_points[kShoulderPoint+kNumArmPoints]);
        arm_points.push_back(chain_points[kElbowPoint+kNumArmPoints]);
        arm_points.push_back(chain_points[kWristPoint+kNumArmPoints]);
        for(int i=0, len=arm_points.size(); i<len; ++i){
            old_arm_points[i] = arm_points[i];
            temp_old_arm_points[i] = arm_points[i];
        }
    } else { // Simulate arm physics
        for(int i=0; i<6; ++i){
            temp_old_arm_points[i] = arm_points[i];
        }
       for(int right=0; right<2; ++right){
           int start = right*3;

            float arm_drag = 0.92f;
            // Determine how loose the arms should be
            float arm_loose = 1.0f-length(this_mo.velocity)/max_speed;
            if(idle_type == _combat){
                arm_loose = 0.0f;
            }
            if(!on_ground){
                arm_loose = 0.7f;
            }
            if(flip_info.IsFlipping()){
                arm_loose = 0.0f;
            }
            arm_loose = max(0.0f, arm_loose - threat_amount);
            float arm_stiffness = mix(0.9f, 0.97f, arm_loose);
            float shoulder_stiffness = arm_stiffness;
            float elbow_stiffness = arm_stiffness;

            vec3 shoulder = chain_points[kShoulderPoint + kNumArmPoints*right];
            vec3 elbow = chain_points[kElbowPoint + kNumArmPoints*right];
            vec3 wrist = chain_points[kWristPoint + kNumArmPoints*right];
            arm_points[start+0] = shoulder;
            { // Apply arm velocity
                vec3 full_vel_offset = this_mo.velocity * time_step * num_frames;
                vec3 vel_offset = ((arm_points[start+1] - old_arm_points[start+1]) - full_vel_offset) * pow(arm_drag, num_frames) + full_vel_offset;
                arm_points[start+1] += vel_offset;
                vel_offset = ((arm_points[start+2] - old_arm_points[start+2]) - full_vel_offset) * pow(arm_drag, num_frames) + full_vel_offset;
                arm_points[start+2] += vel_offset;
            }
            quaternion rotation;
            { // Apply linear force towards target positions
                arm_points[start+1] += (elbow - arm_points[start+1]) * (1.0f - pow(shoulder_stiffness, num_frames));
                GetRotationBetweenVectors(elbow-shoulder, arm_points[start+1]-shoulder, rotation);
                vec3 rotated_tip = Mult(rotation, wrist-elbow)+elbow;
                arm_points[start+2] += (rotated_tip - arm_points[start+2]) * (1.0f - pow(elbow_stiffness, num_frames));
            }
            float softness_override = rigged_object.GetStatusKeyValue(right==1?"rightarm_blend":"leftarm_blend");
            //softness_override = mix(softness_override, 1.0f, min(1.0f, flip_ik_fade));
            if(ledge_info.on_ledge){
                softness_override = 1.0f;
            }
            { // Blend with original position to override physics
                arm_points[start+0] = mix(arm_points[start+0], shoulder, softness_override);
                arm_points[start+1] = mix(arm_points[start+1], elbow, softness_override);
                arm_points[start+2] = mix(arm_points[start+2], wrist, softness_override);
            }
            
            { // Enforce constraints
                // Get hinge joint info
                int chain_start = ik_chain_start_index[kLeftArmIK+right];
                BoneTransform elbow_mat = rigged_object.GetFrameMatrix(ik_chain_elements[chain_start+3]);
                vec3 elbow_axis = Mult(rotation, elbow_mat.rotation * vec3(1,0,0));
                vec3 elbow_front = Mult(rotation, elbow_mat.rotation * vec3(0,1,0));
                vec3 shoulder_offset, elbow_offset, wrist_offset;

                for(int i=0; i<1; ++i){
                    float iter_strength = 0.75f * (1.0f - softness_override);

                    // Distance constraints
                    elbow_offset = (shoulder + normalize(arm_points[start+1]-shoulder) * upper_arm_length[right]) - arm_points[start+1];
                    vec3 mid = (arm_points[start+1] + arm_points[start+2])*0.5f;
                    vec3 dir = normalize(arm_points[start+1] - arm_points[start+2]);
                    wrist_offset = (mid - dir * lower_arm_length[right] * 0.5f) - arm_points[start+2];
                    elbow_offset += (mid + dir * lower_arm_length[right] * 0.5f) - arm_points[start+1];

                    // Hinge constraints
                    vec3 offset;
                    offset += elbow_axis * dot(elbow_axis, arm_points[start+2]-arm_points[start+1]);
                    float front_amount = dot(elbow_front, arm_points[start+2]-arm_points[start+1]);
                    if(front_amount < 0.0f){
                        offset += elbow_front * front_amount;        
                    }
                    elbow_offset += offset * 0.5f;
                    wrist_offset -= offset * 0.5f;

                    // Apply scaled correction vectors
                    arm_points[start+1] += elbow_offset * iter_strength;
                    arm_points[start+2] += wrist_offset * iter_strength;
                }
            }
        }
        /*{ // Apply arm physics to actual elbow, hand and wrist positions
            int point_offset = kNumArmPoints;
            vec3 hand = chain_points[kHandPoint+point_offset];
            vec3 wrist = chain_points[kWristPoint+point_offset];
            vec3 elbow = chain_points[kElbowPoint+point_offset];
            int start = 3;
            quaternion hand_rotation;
            GetRotationBetweenVectors(elbow-wrist, arm_points[start+1]-arm_points[start+2], hand_rotation);
            
            vec3 hand_offset = hand-wrist;
            elbow = arm_points[start+1];
            wrist = arm_points[start+2];
            hand = wrist + Mult(hand_rotation, hand_offset);

            BoneTransform temp_r_hand_transform;
            temp_r_hand_transform.origin = (wrist+hand) * 0.5f;
            temp_r_hand_transform.rotation = hand_rotation * right_hand.rotation;
            BoneTransform temp_l_hand_transform = temp_r_hand_transform*invert(right_hand)*left_hand;
            vec3 offset = temp_l_hand_transform.origin - arm_points[2];
            arm_points[2] += offset * 0.5f;
            //arm_points[5] -= offset * 0.5f;
        }*/
        for(int i=0; i<6; ++i){
            old_arm_points[i] = temp_old_arm_points[i];
        }
    }

    for(int right=0; right<2; ++right){
        int chain_start = ik_chain_start_index[kLeftArmIK+right];
        int point_offset = right * kNumArmPoints;
        vec3 hand = chain_points[kHandPoint+point_offset];
        vec3 wrist = chain_points[kWristPoint+point_offset];
        vec3 elbow = chain_points[kElbowPoint+point_offset];
        vec3 shoulder = chain_points[kShoulderPoint+point_offset];
        vec3 collar_tip = chain_points[kCollarTipPoint+point_offset];
        vec3 collar = chain_points[kCollarPoint+point_offset];

        { // Apply arm physics to actual elbow, hand and wrist positions
            int start = right*3;
            quaternion hand_rotation;
            GetRotationBetweenVectors(elbow-wrist, arm_points[start+1]-arm_points[start+2], hand_rotation);
            
            vec3 hand_offset = hand-wrist;
            elbow = arm_points[start+1];
            wrist = arm_points[start+2];
            hand = wrist + Mult(hand_rotation, hand_offset);
        }

        if(draw_skeleton_lines){
            debug_lines.push_back(DebugDrawLine(hand, wrist, vec3(1.0f), _fade));
            debug_lines.push_back(DebugDrawLine(wrist, elbow, vec3(1.0f), _fade));
            debug_lines.push_back(DebugDrawLine(elbow, shoulder, vec3(1.0f), _fade));
            debug_lines.push_back(DebugDrawLine(collar, shoulder, vec3(1.0f), _fade));
        }

        BoneTransform old_hand_matrix = rigged_object.GetFrameMatrix(ik_chain_elements[chain_start+0]);

        for(int i=4, len=ik_chain_length[kLeftArmIK+right]; i<len; ++i){
            rigged_object.SetFrameMatrix(ik_chain_elements[chain_start+i], rel_mat * rigged_object.GetFrameMatrix(ik_chain_elements[chain_start+i]));
        }

        rigged_object.RotateBoneToMatchVec(collar, collar_tip, ik_chain_elements[chain_start+5]);
        rigged_object.RotateBoneToMatchVec(shoulder, mix(shoulder, elbow, upper_arm_weight[right]), ik_chain_elements[chain_start+4]);
        rigged_object.RotateBoneToMatchVec(mix(shoulder, elbow, upper_arm_weight[right]), elbow, ik_chain_elements[chain_start+3]);
        rigged_object.RotateBoneToMatchVec(elbow, mix(elbow, wrist, lower_arm_weight[right]), ik_chain_elements[chain_start+2]);
        rigged_object.RotateBoneToMatchVec(mix(elbow, wrist, lower_arm_weight[right]), wrist, ik_chain_elements[chain_start+1]);
        BoneTransform hand_transform = right==1?r_hand_transform:l_hand_transform;
        rigged_object.SetFrameMatrix(ik_chain_elements[chain_start+0], hand_transform * inv_skeleton_bind_transforms[ik_chain_elements[chain_start+0]]);
        rigged_object.RotateBoneToMatchVec(wrist, hand, ik_chain_elements[chain_start+0]);
        
        BoneTransform hand_rel = rigged_object.GetFrameMatrix(ik_chain_elements[chain_start+0]) * invert(old_hand_matrix);

        // Apply hand rotation to child bones (like fingers)
        for(int i=0, len=GetNumBoneChildren(ik_chain_elements[chain_start+0]); i<len; ++i){
            int child = GetBoneChild(ik_chain_elements[chain_start+0], i);
            rigged_object.SetFrameMatrix(child, hand_rel * rigged_object.GetFrameMatrix(child));
        }
    }
    LeaveTelemetryZone();
}

array<vec3> temp_old_ear_points;
array<vec3> old_ear_points;
array<vec3> ear_points;

array<float> target_ear_rotation;
array<float> ear_rotation;
array<float> ear_rotation_time;

void DrawEar(bool right, const BoneTransform &in head_transform, int num_frames){
    EnterTelemetryZone("DrawEar");
    RiggedObject@ rigged_object = this_mo.rigged_object();
    Skeleton@ skeleton = rigged_object.skeleton();

    int chain_start = ik_chain_start_index[kLeftEarIK+(right?1:0)];

    vec3 tip, middle, base;
    tip = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+0], 1);
    middle = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+0], 0);
    base = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+1], 0);

    if(ear_rotation.size()==0){
        ear_rotation.resize(2);
        ear_rotation_time.resize(2);
        target_ear_rotation.resize(2);
        for(int i=0; i<2; ++i){
            target_ear_rotation[i] = 0.0f;
            ear_rotation[i] = 0.0f;
            ear_rotation_time[i] = 0.0f;
        }
    } else {
        int which = right?1:0;
        if(ear_rotation_time[which] < time){
            target_ear_rotation[which] = RangedRandomFloat(-0.4f, 0.8f);
            ear_rotation_time[which] = time+RangedRandomFloat(0.7f, 4.0f);
        }
        ear_rotation[which] = mix(target_ear_rotation[which], ear_rotation[which], pow(0.9f,num_frames));
    }

    bool ear_rotate_test = true;
    if(ear_rotate_test){
        vec3 head_up = head_transform.rotation * inv_skeleton_bind_transforms[ik_chain_elements[ik_chain_start_index[kHeadIK]]].rotation * vec3(0,0,1);
        vec3 head_dir = head_transform.rotation * inv_skeleton_bind_transforms[ik_chain_elements[ik_chain_start_index[kHeadIK]]].rotation * vec3(0,1,0);
        vec3 head_right = cross(head_dir, head_up);
        //float ear_back_amount = 2.5f;
        //float ear_twist_amount = 3.0f * (right?-1.0f:1.0f);
        float ear_back_amount = 0.0f;
        float ear_twist_amount = ear_rotation[right?1:0];
        if(right){
            ear_twist_amount *= -1.0f;
        }
        if(character_getter.GetTag("species") != "rabbit"){
            ear_twist_amount *= 0.3f;
        }
        BoneTransform ear_back_mat;
        vec3 ear_right = normalize(cross(head_dir, middle-base));
        ear_back_mat.rotation = quaternion(vec4(ear_right, ear_back_amount));
        BoneTransform ear_twist_mat;
        ear_twist_mat.rotation = quaternion(vec4(ear_back_mat.rotation*normalize(middle-base), ear_twist_amount));
        BoneTransform base_offset;
        base_offset.origin = base;
        BoneTransform ear_transform = base_offset * ear_twist_mat * ear_back_mat * invert(base_offset);
        BoneTransform tip_ear_transform = base_offset * ear_twist_mat * ear_twist_mat * ear_back_mat * invert(base_offset);
        rigged_object.SetFrameMatrix(ik_chain_elements[chain_start+0], tip_ear_transform * rigged_object.GetFrameMatrix(ik_chain_elements[chain_start+0]));
        rigged_object.SetFrameMatrix(ik_chain_elements[chain_start+1], ear_transform * rigged_object.GetFrameMatrix(ik_chain_elements[chain_start+1]));

        tip = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+0], 1);
        middle = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+0], 0);
    }

    float low_dist = distance(base, middle);
    float high_dist = distance(middle, tip);

    old_ear_points.resize(6);
    temp_old_ear_points.resize(6);
    if(ear_points.size()!=6){
        ear_points.push_back(base);
        ear_points.push_back(middle);
        ear_points.push_back(tip);
        for(int i=0, len=ear_points.size(); i<len; ++i){
            old_ear_points[i] = ear_points[i];
            temp_old_ear_points[i] = ear_points[i];
        }
    } else {
        int start = right?3:0;

        for(int i=0; i<3; ++i){
            temp_old_ear_points[start+i] = ear_points[start+i];
        }

        float ear_damping = 0.95f;
        float low_ear_rotation_damping = 0.9f;
        float up_ear_rotation_damping = 0.92f;

        ear_points[start+0] = base;
        vec3 vel_offset = this_mo.velocity * time_step * num_frames;
        ear_points[start+1] += (((ear_points[start+1] - old_ear_points[start+1]) - vel_offset) * pow(ear_damping, num_frames) + vel_offset) * ear_damping * ear_damping;
        ear_points[start+2] += (((ear_points[start+2] - old_ear_points[start+2]) - vel_offset) * pow(ear_damping, num_frames) + vel_offset) * ear_damping * ear_damping;
         quaternion rotation;
        GetRotationBetweenVectors(middle-base, ear_points[start+1]-base, rotation);
        vec3 rotated_tip = Mult(rotation, tip-middle)+ear_points[start+1];
        ear_points[start+2] += (rotated_tip - ear_points[start+2]) * (1.0f - pow(up_ear_rotation_damping, num_frames));
        ear_points[start+1] += (middle - ear_points[start+1]) * (1.0f - pow(low_ear_rotation_damping, num_frames));
       
        for(int i=0; i<3; ++i){
            ear_points[start+1] = base + normalize(ear_points[start+1]-base) * low_dist;
            vec3 mid = (ear_points[start+1] + ear_points[start+2])*0.5f;
            vec3 dir = normalize(ear_points[start+1] - ear_points[start+2]);
            ear_points[start+2] = mid - dir * high_dist * 0.5f;
            ear_points[start+1] = mid + dir * high_dist * 0.5f;
        }

        if(flip_info.IsFlipping() && on_ground){
            col.GetSweptSphereCollision(ear_points[start+0], ear_points[start+1], 0.03f);
            ear_points[start+1] = sphere_col.adjusted_position;
            col.GetSweptSphereCollision(ear_points[start+1], ear_points[start+2], 0.03f);
            ear_points[start+2] = sphere_col.adjusted_position;
        }

        //debug_lines.push_back(DebugDrawLine(ear_points[start+0], ear_points[start+1], vec3(1.0f), _fade));
        //debug_lines.push_back(DebugDrawLine(ear_points[start+1], ear_points[start+2], vec3(1.0f), _fade));
        rigged_object.RotateBoneToMatchVec(ear_points[start+0], ear_points[start+1], ik_chain_elements[chain_start+1]);
        rigged_object.RotateBoneToMatchVec(ear_points[start+1], ear_points[start+2], ik_chain_elements[chain_start+0]);
        middle = ear_points[start+1];
        tip = ear_points[start+2];
    
        for(int i=0; i<3; ++i){
            old_ear_points[start+i] = temp_old_ear_points[start+i];
        }
    }
    
    if(draw_skeleton_lines){
        debug_lines.push_back(DebugDrawLine(tip, middle, vec3(1.0f), _fade));
        debug_lines.push_back(DebugDrawLine(middle, base, vec3(1.0f), _fade));
    }
    LeaveTelemetryZone();
}

void ResetSecondaryAnimation() {
    ear_rotation.resize(0);
    tail_points.resize(0);
    arm_points.resize(0);
    ear_points.resize(0);
    old_foot_offset.resize(0);
    old_foot_rotate.resize(0);
    weap_points.resize(0);
    old_hip_offset = vec3(0.0f);
}


array<vec3> temp_old_tail_points;
array<vec3> old_tail_points;
array<vec3> tail_points;
array<vec3> tail_correction;
array<float> tail_section_length;

void DrawTail(int num_frames){
    if(ik_chain_length[kTailIK]==0){
        return; // This character has no tail!
    }
    EnterTelemetryZone("DrawTail");

    RiggedObject@ rigged_object = this_mo.rigged_object();
    Skeleton@ skeleton = rigged_object.skeleton();

    int chain_start = ik_chain_start_index[kTailIK];
    int chain_length = ik_chain_length[kTailIK];

    // Tail wag behavior
    bool wag_tail = false;
    if(wag_tail){
        float wag_freq = 5.0f;
        vec3 tail_root = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+chain_length-1], 0);
        int hip_bone = skeleton.GetParent(ik_chain_elements[chain_start+chain_length-1]);
        vec3 axis = rigged_object.GetFrameMatrix(hip_bone).rotation * vec3(0,0,1);
        quaternion rotation(vec4(axis.x,axis.y,axis.z,sin(time*wag_freq)));
        for(int i=0, len=chain_length; i<len; ++i){
            BoneTransform mat = rigged_object.GetFrameMatrix(ik_chain_elements[chain_start+i]);
            mat.origin -= tail_root;
            mat = rotation * mat;
            mat.origin += tail_root;
            rigged_object.SetFrameMatrix(ik_chain_elements[chain_start+i], mat);
        }
    }

    bool ambient_tail = false;
    if(ambient_tail){
        vec3 tail_root = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+chain_length-1], 0);
        int hip_bone = skeleton.GetParent(ik_chain_elements[chain_start+chain_length-1]);
        vec3 axis = rigged_object.GetFrameMatrix(hip_bone).rotation * vec3(0,0,1);
        quaternion rotation(vec4(axis.x,axis.y,axis.z,(sin(time)+sin(time*1.3))*0.2f));
        for(int i=0, len=chain_length; i<len; ++i){
            BoneTransform mat = rigged_object.GetFrameMatrix(ik_chain_elements[chain_start+i]);
            mat.origin -= tail_root;
            mat = rotation * mat;
            mat.origin += tail_root;
            rigged_object.SetFrameMatrix(ik_chain_elements[chain_start+i], mat);
        }
    }

    bool twitch_tail_tip = false;
    if(twitch_tail_tip){
        float wag_freq = 5.0f;
        vec3 tail_root = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+0], 0);
        int hip_bone = skeleton.GetParent(ik_chain_elements[chain_start+chain_length-1]);
        vec3 axis = rigged_object.GetFrameMatrix(hip_bone).rotation * vec3(0,0,1);
        quaternion rotation(vec4(axis.x,axis.y,axis.z,sin(time*wag_freq)));
        for(int i=0; i<1; ++i){
            BoneTransform mat = rigged_object.GetFrameMatrix(ik_chain_elements[chain_start+i]);
            mat.origin -= tail_root;
            mat = rotation * mat;
            mat.origin += tail_root;
            rigged_object.SetFrameMatrix(ik_chain_elements[chain_start+i], mat);
        }
    }

    tail_section_length.resize(chain_length);
    tail_correction.resize(chain_length+1);
    old_tail_points.resize(chain_length+1);
    temp_old_tail_points.resize(chain_length+1);
    if(tail_points.size()==0){
        tail_points.resize(chain_length+1);
        for(int i=0; i<chain_length; ++i){
            tail_points[i] = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+i], 1);
            old_tail_points[i] = tail_points[i];
            temp_old_tail_points[i] = tail_points[i];
        }
        tail_points[chain_length] = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+chain_length-1], 0);
        for(int i=0; i<chain_length; ++i){
            tail_section_length[i] = distance(tail_points[i], tail_points[i+1]); 
        }
    } else {
        tail_points[chain_length] = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+chain_length-1], 0);
        for(int i=0; i<chain_length+1; ++i){
            temp_old_tail_points[i] = tail_points[i];
        }
        for(int i=0; i<chain_length; ++i){
            tail_points[i] += (tail_points[i] - old_tail_points[i]) * 0.95f;
        }
        for(int i=0; i<chain_length; ++i){
            tail_points[i].y -= time_step * num_frames * 0.1f;
        }
        tail_correction[chain_length-1] += (rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+chain_length-1], 1) - tail_points[chain_length-1])  * (1.0f - pow(0.9f, num_frames));
        for(int i=chain_length-2; i>=0; --i){
            vec3 offset = rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+i], 1) - rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+i+1], 1);
            quaternion rotation;
            GetRotationBetweenVectors(rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+i+1], 1) - rigged_object.GetTransformedBonePoint(ik_chain_elements[chain_start+i+1], 0), tail_points[i+1]-tail_points[i+2], rotation);
            tail_correction[i] = ((tail_points[i+1]+Mult(rotation, offset)) - tail_points[i]) * (0.2f) * 0.5f;
            tail_correction[i+1] -= tail_correction[i];
        }
        for(int i=chain_length-1; i>=0; --i){
            tail_points[i] += tail_correction[i];
        }      

        for(int j=0, len=max(5, int(num_frames*1.5)); j<len; ++j){
            for(int i=0; i<chain_length+1; ++i){
                tail_correction[i] = vec3(0.0f);
            }
            for(int i=0; i<chain_length; ++i){
                vec3 mid = (tail_points[i] + tail_points[i+1])*0.5f;
                vec3 dir = normalize(tail_points[i]-tail_points[i+1]);
                tail_correction[i] += (mid + dir*tail_section_length[i]*0.5f - tail_points[i])*0.75f;
                tail_correction[i+1] += (mid - dir*tail_section_length[i]*0.5f - tail_points[i+1])*0.25f;
            }
            for(int i=chain_length-1; i>=0; --i){
                tail_points[i] += tail_correction[i] * min(1.0f, (0.5f + j*0.125f));
            }
        }

        for(int i=chain_length-1; i>=0; --i){
            col.GetSweptSphereCollision(tail_points[i+1], tail_points[i], 0.03f);
            tail_points[i] = sphere_col.adjusted_position;
        } 

        for(int i=0; i<chain_length+1; ++i){
            old_tail_points[i] = temp_old_tail_points[i];
        }
    }


    for(int i=0; i<chain_length; ++i){
        rigged_object.RotateBoneToMatchVec(tail_points[i+1], tail_points[i], ik_chain_elements[chain_start+i]);        
    }
    if(draw_skeleton_lines){
        for(int i=0; i<chain_length; ++i){
            debug_lines.push_back(DebugDrawLine(tail_points[i], tail_points[i+1], vec3(1.0f), _fade));
        }
    }
    LeaveTelemetryZone();
}

void DrawBody(const BoneTransform &in hip_transform, const BoneTransform &in chest_transform){
    EnterTelemetryZone("DrawBody");
    RiggedObject@ rigged_object = this_mo.rigged_object();
    Skeleton@ skeleton = rigged_object.skeleton();

    int start = ik_chain_start_index[kTorsoIK];

    BoneTransform old_hip_matrix = rigged_object.GetFrameMatrix(ik_chain_elements[start+2]);

    int chest_bone = ik_chain_elements[start+0];
    int abdomen_bone = ik_chain_elements[start+1];
    int hip_bone = ik_chain_elements[start+2];

    vec3 collarbone = chest_transform * skeleton.GetPointPos(skeleton.GetBonePoint(chest_bone, 1));
    vec3 ribs = chest_transform * skeleton.GetPointPos(skeleton.GetBonePoint(chest_bone, 0));
    vec3 stomach = hip_transform * skeleton.GetPointPos(skeleton.GetBonePoint(abdomen_bone, 0));
    vec3 hips = hip_transform * skeleton.GetPointPos(skeleton.GetBonePoint(hip_bone, 0));
    
    if(draw_skeleton_lines){
        debug_lines.push_back(DebugDrawLine(collarbone, ribs, vec3(1.0f), _fade));
        debug_lines.push_back(DebugDrawLine(ribs, stomach, vec3(1.0f), _fade));
        debug_lines.push_back(DebugDrawLine(stomach, hips, vec3(1.0f), _fade));
    }

    rigged_object.SetFrameMatrix(chest_bone, chest_transform * inv_skeleton_bind_transforms[chest_bone]);
    BoneTransform temp = mix(chest_transform, hip_transform, 0.5f);
    temp.rotation = mix(hip_transform.rotation, chest_transform.rotation, 0.5f);
    rigged_object.SetFrameMatrix(abdomen_bone, temp * inv_skeleton_bind_transforms[abdomen_bone]);
    

    rigged_object.RotateBoneToMatchVec(ribs, collarbone, chest_bone);
    rigged_object.RotateBoneToMatchVec(stomach, ribs, abdomen_bone);
    rigged_object.RotateBoneToMatchVec(hips, stomach, hip_bone);

    BoneTransform hip_rel = rigged_object.GetFrameMatrix(hip_bone) * invert(old_hip_matrix);

    start = ik_chain_start_index[kTailIK];
    int len = ik_chain_length[kTailIK];

    for(int i=0; i<len; ++i){
        int bone = ik_chain_elements[start+i];
        rigged_object.SetFrameMatrix(bone, hip_rel * rigged_object.GetFrameMatrix(bone));
    }
    LeaveTelemetryZone();
}

void DrawHead(const BoneTransform &in chest_transform, const BoneTransform &in head_transform, int num_frames){
    EnterTelemetryZone("DrawHead");
    RiggedObject@ rigged_object = this_mo.rigged_object();
    Skeleton@ skeleton = rigged_object.skeleton();

    int start = ik_chain_start_index[kHeadIK];
    int head_bone = ik_chain_elements[start+0];
    int neck_bone = ik_chain_elements[start+1];

    int chest_bone = ik_chain_elements[ik_chain_start_index[kTorsoIK]];
    BoneTransform chest_frame_matrix = rigged_object.GetFrameMatrix(chest_bone);
    BoneTransform chest_bind_matrix = skeleton_bind_transforms[chest_bone];
    BoneTransform rel_mat = chest_transform * invert(BoneTransform(chest_frame_matrix * chest_bind_matrix));

    BoneTransform old_head_matrix = rigged_object.GetFrameMatrix(head_bone);

    vec3 crown, skull, neck;
    crown = head_transform * skeleton.GetPointPos(skeleton.GetBonePoint(head_bone, 1));
    skull = head_transform * skeleton.GetPointPos(skeleton.GetBonePoint(head_bone, 0));
    neck = chest_transform * skeleton.GetPointPos(skeleton.GetBonePoint(neck_bone, 0));

    BoneTransform world_chest = key_transforms[kChestKey] * inv_skeleton_bind_transforms[ik_chain_start_index[kTorsoIK]];
    vec3 breathe_dir = world_chest.rotation * normalize(vec3(0,-0.3,1));
    float scale = this_mo.rigged_object().GetCharScale();
    skull += breathe_dir * breath_amount * 0.005f * scale;
    crown += breathe_dir * breath_amount * 0.002f * scale;
    

    if(draw_skeleton_lines){
        debug_lines.push_back(DebugDrawLine(crown, skull, vec3(1.0f), _fade));
        debug_lines.push_back(DebugDrawLine(skull, neck, vec3(1.0f), _fade));
    }
    
    rigged_object.SetFrameMatrix(head_bone, head_transform * inv_skeleton_bind_transforms[head_bone]);
    rigged_object.RotateBoneToMatchVec(neck, skull, neck_bone);
    rigged_object.RotateBoneToMatchVec(skull, crown, head_bone);

    BoneTransform head_rel = rigged_object.GetFrameMatrix(head_bone) * invert(old_head_matrix);

    for(int i=0, len=GetNumBoneChildren(head_bone); i<len; ++i){
        int child = GetBoneChild(head_bone, i);
        rigged_object.SetFrameMatrix(child, head_rel * rigged_object.GetFrameMatrix(child));
    }
    LeaveTelemetryZone();
}

// Key transform enums
const int kHeadKey = 0;
const int kLeftArmKey = 1;
const int kRightArmKey = 2;
const int kLeftLegKey = 3;
const int kRightLegKey = 4;
const int kChestKey = 5;
const int kHipKey = 6;
const int kNumKeys = 7;

array<float> key_masses;
array<int> root_bone;

vec3 GetCenterOfMassEstimate(array<BoneTransform> &in key_transforms){
    RiggedObject@ rigged_object = this_mo.rigged_object();
    Skeleton@ skeleton = rigged_object.skeleton();

    bool show_debug_info = false;

    // Estimate center of mass
    vec3 estimate_com;
    float body_mass = 0.0f;
    for(int j=0; j<2; ++j){
        int bone = ik_chain_elements[ik_chain_start_index[kLeftLegIK+j]];
        vec3 point = skeleton.GetPointPos(skeleton.GetBonePoint(bone, 0));
        vec3 foot_point = key_transforms[kLeftLegKey+j] * point;
        vec3 hip_point = key_transforms[kHipKey] * skeleton.GetPointPos(skeleton.GetBonePoint(root_bone[kLeftLegKey+j], 0));
        estimate_com += (hip_point + foot_point)*0.5f*key_masses[kLeftLegKey+j];
        body_mass += key_masses[kLeftLegKey+j];
        if(show_debug_info){
            debug_lines.push_back(DebugDrawLine(hip_point, foot_point, vec3(1.0f,0.0f,0.0f), _fade));
            debug_lines.push_back(DebugDrawWireSphere((hip_point + foot_point)*0.5f, pow(key_masses[kLeftLegKey+j], 0.33f) * 0.05f, vec3(1.0f), _fade));
        }
    }
    for(int j=0; j<2; ++j){
        int bone = ik_chain_elements[ik_chain_start_index[kLeftArmIK+j]];
        vec3 foot_point = key_transforms[j==0?kLeftArmKey:kRightArmKey] * skeleton.GetPointPos(skeleton.GetBonePoint(bone, 0));
        vec3 hip_point = key_transforms[kChestKey] * skeleton.GetPointPos(skeleton.GetBonePoint(root_bone[kLeftArmKey+j], 0));
        estimate_com += (hip_point + foot_point)*0.5f*key_masses[kLeftArmKey+j];
        body_mass += key_masses[kLeftArmKey+j];
        if(show_debug_info){
            debug_lines.push_back(DebugDrawLine(hip_point, foot_point, vec3(1.0f,0.0f,0.0f), _fade));
            debug_lines.push_back(DebugDrawWireSphere((hip_point + foot_point)*0.5f, pow(key_masses[kLeftArmKey+j], 0.33f) * 0.05f, vec3(1.0f), _fade));
        }
    }
    {
        int bone = ik_chain_elements[ik_chain_start_index[kTorsoIK]];
        vec3 foot_point = key_transforms[kChestKey] * skeleton.GetPointPos(skeleton.GetBonePoint(bone, 1));
        vec3 hip_point = key_transforms[kHipKey] * skeleton.GetPointPos(skeleton.GetBonePoint(root_bone[kChestKey], 0));
        estimate_com += (hip_point + foot_point)*0.5f*key_masses[kChestKey];
        body_mass += key_masses[kChestKey];
        if(show_debug_info){
            debug_lines.push_back(DebugDrawLine(hip_point, foot_point, vec3(1.0f,0.0f,0.0f), _fade));
            debug_lines.push_back(DebugDrawWireSphere((hip_point + foot_point)*0.5f, pow(key_masses[kChestKey], 0.33f) * 0.05f, vec3(1.0f), _fade));
        }
    }
    {
        int bone = ik_chain_elements[ik_chain_start_index[kHeadIK]];
        vec3 foot_point = key_transforms[kHeadKey] * skeleton.GetPointPos(skeleton.GetBonePoint(bone, 1));
        vec3 hip_point = key_transforms[kChestKey] * skeleton.GetPointPos(skeleton.GetBonePoint(root_bone[kHeadKey], 0));
        estimate_com += (hip_point + foot_point)*0.5f*key_masses[kHeadKey];
        body_mass += key_masses[kHeadKey];
        if(show_debug_info){
            debug_lines.push_back(DebugDrawLine(hip_point, foot_point, vec3(1.0f,0.0f,0.0f), _fade));
            debug_lines.push_back(DebugDrawWireSphere((hip_point + foot_point)*0.5f, pow(key_masses[kHeadKey], 0.33f) * 0.05f, vec3(1.0f), _fade));
       }
    }
    if(show_debug_info){
        debug_lines.push_back(DebugDrawWireSphere(estimate_com/body_mass, 0.1f, vec3(0.0f,1.0f,0.0f), _fade));
    }
    return estimate_com/body_mass;
}

float MoveTowards(float start, float target, float speed){
    if(abs(target-start)<speed){
        return target;
    } else if(target > start){
        return start + speed;
    } else {
        return start - speed;
    }
}

vec3 old_com;
vec3 old_com_vel;
vec3 old_hip_offset;
array<float> old_foot_offset;
array<quaternion> old_foot_rotate;

vec3 old_head_facing;
vec2 old_angle;
vec2 head_angle;
vec2 target_head_angle;
vec2 head_angle_vel;
vec2 head_angle_accel;
float old_head_angle;

vec3 old_chest_facing;
vec2 old_chest_angle_vec;
vec2 chest_angle;
vec2 target_chest_angle;
vec2 chest_angle_vel;
float old_chest_angle;
float ragdoll_fade_speed = 1000.0f;
float preserve_angle_strength = 0.0f;

quaternion total_body_rotation;

void AddIKBonesToArray(array<int> &inout bones, int which){
    Skeleton @skeleton = this_mo.rigged_object().skeleton();
    int start = ik_chain_start_index[which];
    int end = ik_chain_start_index[which+1];
    for(int i=start; i<end; ++i){
        bones.push_back(ik_chain_elements[i]);
    }
}

quaternion GetFrameRotation() {
    mat4 transform2 = GetFrameAverageDeltaMatrix();
    mat4 flip_rotation = transform2.GetRotationPart();
    vec3 a = flip_rotation.GetColumn(0);
    vec3 b = flip_rotation.GetColumn(1);
    vec3 c = flip_rotation.GetColumn(2);
    // orthonormalize
    for(int i=0; i<5; ++i){
        a = normalize(a);
        b = normalize(b);
        c = normalize(c);
        vec3 new_a, new_b, new_c;
        new_a = a-dot(a,b)*b*0.5f-dot(a,c)*c*0.5f;
        new_b = b-dot(a,b)*a*0.5f-dot(b,c)*c*0.5f;
        new_c = c-dot(a,c)*a*0.5f-dot(b,c)*b*0.5f;
        a = mix(a, new_a, 0.5f);
        b = mix(b, new_b, 0.5f);
        c = mix(c, new_c, 0.5f);
    }
    flip_rotation.SetColumn(0, normalize(a));
    flip_rotation.SetColumn(1, normalize(b));
    flip_rotation.SetColumn(2, normalize(c));    
    return QuaternionFromMat4(flip_rotation);
}


BoneTransform ApplyParentRotations(array<BoneTransform> &in matrices, int id) {
    int parent_id = this_mo.rigged_object().skeleton().GetParent(id);
    if(parent_id == -1){
        return matrices[id];    
    } else {
        return ApplyParentRotations(matrices,parent_id) * matrices[id];
    }
}

uint64 perf_count;

void StartPerfCount() {
    perf_count = GetPerformanceCounter();
}

void DisplayPerfCount(int num) {
    uint64 new_perf_count = GetPerformanceCounter();
    DebugText("count"+((num<10)?"0":"")+num, "count"+num+": "+(new_perf_count - perf_count), 0.5f);
    perf_count = GetPerformanceCounter();
}

float last_changed_com = 0.0f;
vec3 com_offset;
vec3 com_offset_vel;
vec3 target_com_offset;
    
array<int> roll_check_bones;
array<BoneTransform> key_transforms;
array<float> target_leg_length;
void FinalAnimationMatrixUpdate(int num_frames) {
    // Clear debug lines
    for(int i=0, len=debug_lines.size(); i<len; ++i){
        DebugDrawRemove(debug_lines[i]);
    }
    debug_lines.resize(0);

    // Convenient shortcuts
    RiggedObject@ rigged_object = this_mo.rigged_object();
    Skeleton@ skeleton = rigged_object.skeleton();    

    // Get local to world transform
    BoneTransform local_to_world;
    {
        EnterTelemetryZone("get local_to_world transform");
        float ground_conform = this_mo.rigged_object().GetStatusKeyValue("groundconform");
        if(ground_conform > 0.0f){
            ground_conform = min(1.0f, ground_conform);
            
            vec3 a(0,1,0);
            vec3 b = ground_normal;
            vec3 rotate_axis = normalize(cross(a, b));
            vec3 up = normalize(a);
            vec3 right_vec = cross(up, rotate_axis);
            vec3 ik_dir = normalize(b);
            float rotate_angle = atan2(-dot(ik_dir, right_vec), dot(ik_dir, up));
            
            flip_modifier_axis = rotate_axis;
            flip_modifier_rotation = rotate_angle*ground_conform;
        }

        vec3 offset;
        offset = this_mo.position;
        offset.y -= _leg_sphere_size;

        vec3 facing = this_mo.GetFacing();
        float cur_rotation = atan2(facing.x, facing.z);
        quaternion rotation(vec4(0,1,0,cur_rotation));

        local_to_world.rotation = rotation;
        local_to_world.origin = offset;

        rigged_object.TransformAllFrameMats(local_to_world);

        vec3 frame_com = rigged_object.GetFrameCenterOfMass();

        BoneTransform flip_modifier;
        flip_modifier.origin = frame_com * -1.0f;
        BoneTransform flip_rotation;
        flip_rotation.rotation = quaternion(vec4(flip_modifier_axis.x, flip_modifier_axis.y, flip_modifier_axis.z, flip_modifier_rotation));
        vec3 tilt_axis = normalize(cross(vec3(0.0f, 1.0f, 0.0f), tilt_modifier));
        BoneTransform tilt_rotation;
        tilt_rotation.rotation = quaternion(vec4(tilt_axis.x, tilt_axis.y, tilt_axis.z, length(tilt_modifier)/180.0f*3.1417f));
        flip_modifier = flip_rotation * tilt_rotation * flip_modifier;
        flip_modifier.origin += frame_com;

        rigged_object.TransformAllFrameMats(flip_modifier);

        local_to_world = flip_modifier * local_to_world;

        // Update offset to handle roll contacts
        if(flip_info.IsFlipping() && on_ground && convex_hull_points.size()>0){
            roll_check_bones.resize(0);
            AddIKBonesToArray(roll_check_bones, kLeftLegIK);
            AddIKBonesToArray(roll_check_bones, kRightLegIK);
            AddIKBonesToArray(roll_check_bones, kTorsoIK);
            AddIKBonesToArray(roll_check_bones, kHeadIK);
            AddIKBonesToArray(roll_check_bones, kLeftArmIK);
            AddIKBonesToArray(roll_check_bones, kRightArmIK);

            float low_point = this_mo.position.y;
            int num_convex_points = 0;
            for(int i=0, len=roll_check_bones.size(); i<len; ++i){
                int bone = roll_check_bones[i];
                int num_hull_points = convex_hull_points_index[bone+1]-convex_hull_points_index[bone];
                if(num_hull_points > 0){
                    BoneTransform transformed = rigged_object.GetFrameMatrix(bone);
                    mat3 mat_rot = Mat3FromQuaternion(transformed.rotation);
                    num_convex_points += num_hull_points;
                    for(int j=convex_hull_points_index[bone], len2=convex_hull_points_index[bone+1]; j<len2; ++j){
                        vec3 transformed_point = transformed * convex_hull_points[j];
                        low_point = min(low_point, transformed_point.y);
                        //debug_lines.push_back(DebugDrawWireSphere(transformed_point), 0.01f, vec3(1.0f), _fade));
                    }
                }
            }
            if(num_convex_points != 0){
                vec3 roll_offset = vec3(0,(this_mo.position.y-_leg_sphere_size)-low_point-0.02f,0);
                BoneTransform roll_modifier;
                float roll_offset_scale = 1.0f-pow((abs(0.5 - flip_info.flip_progress)*2.0f),2.0f);
                roll_modifier.origin = roll_offset * roll_offset_scale;

                for(int i=0, len=skeleton.NumBones(); i<len; ++i){
                    rigged_object.SetFrameMatrix(i, roll_modifier * rigged_object.GetFrameMatrix(i));
                }
                local_to_world = roll_modifier * local_to_world;
            }
        }

        // Reduce speed that COM can move downwards during roll
        if(flip_info.IsFlipping() && on_ground){
            vec3 frame_com2 = rigged_object.GetFrameCenterOfMass() - this_mo.position;
            if(old_com == vec3(0.0f) || unragdoll_time > time - 0.5f){
                old_com = frame_com2;
                old_com_vel = this_mo.velocity;
                old_com_vel.x = 0.0f;
                old_com_vel.z = 0.0f;
                old_com_vel.y = -0.5f;
            }
            { 
                old_com += old_com_vel * time_step * num_frames;
                old_com_vel += physics.gravity_vector * time_step * num_frames;
                if(old_com.y < frame_com2.y){
                    old_com.y = frame_com2.y;
                }
                BoneTransform roll_modifier;
                vec3 offset2 = old_com-frame_com2;
                offset2.x *= pow(1.0f-flip_info.flip_progress, 2.0f);
                offset2.z *= pow(1.0f-flip_info.flip_progress, 2.0f);
                roll_modifier.origin = offset2;
                for(int i=0, len=skeleton.NumBones(); i<len; ++i){
                    rigged_object.SetFrameMatrix(i, roll_modifier * rigged_object.GetFrameMatrix(i));
                }
                local_to_world = roll_modifier * local_to_world;
            }

            frame_com2 = rigged_object.GetFrameCenterOfMass() - this_mo.position;
            old_com = frame_com2;
        } else {
            old_com = vec3(0.0f);
        }
        LeaveTelemetryZone();
    }
    if(num_frames > 8){
        ResetSecondaryAnimation();
        return;
    }
    EnterTelemetryZone("inverse kinematics");
    bool draw_ground_plane = false;
    if(draw_ground_plane) {    
        vec3 mid = this_mo.position-vec3(0,_leg_sphere_size,0)*0.99;
        mid += vec3(0,0,0.03);
        vec3 facing = vec3(0,0,1);//this_mo.GetFacing();
        vec3 right = vec3(facing.z, 0.0f, -facing.x);
        debug_lines.push_back(DebugDrawLine(mid-right,mid+right, vec3(1.0f), _fade));
        debug_lines.push_back(DebugDrawLine(mid-facing,mid+facing, vec3(1.0f), _fade));
    }

    // Draw base of support
    const bool draw_base_of_support = false;
    if(draw_base_of_support){
        array<vec3> points;
        points.resize(4);
        int bone = skeleton.IKBoneStart("left_leg");
        BoneTransform transform = rigged_object.GetFrameMatrix(bone);
        BoneTransform bind_matrix = skeleton_bind_transforms[bone];
        transform = transform * bind_matrix;
        points[0] = transform * skeleton.GetPointPos(skeleton.GetBonePoint(bone, 0));
        points[1] = transform * skeleton.GetPointPos(skeleton.GetBonePoint(bone, 1));
        
        bone = skeleton.IKBoneStart("right_leg");
        transform = rigged_object.GetFrameMatrix(bone);
        bind_matrix = skeleton_bind_transforms[bone];
        transform = transform * bind_matrix;
        points[2] = transform * skeleton.GetPointPos(skeleton.GetBonePoint(bone, 0));
        points[3] = transform * skeleton.GetPointPos(skeleton.GetBonePoint(bone, 1));
        debug_lines.push_back(DebugDrawLine(points[0], points[1], vec3(1.0f), _fade));
        debug_lines.push_back(DebugDrawLine(points[1], points[3], vec3(1.0f), _fade));
        debug_lines.push_back(DebugDrawLine(points[2], points[3], vec3(1.0f), _fade));
        debug_lines.push_back(DebugDrawLine(points[2], points[0], vec3(1.0f), _fade));
    }

    key_transforms.resize(kNumKeys);

    // Get key points from animation
    for(int j=0; j<2; ++j){
        int bone = ik_chain_elements[ik_chain_start_index[kLeftLegIK+j]];
        key_transforms[kLeftLegKey+j] = rigged_object.GetFrameMatrix(bone) * skeleton_bind_transforms[bone];
    }
    for(int j=0; j<2; ++j){
        int bone = ik_chain_elements[ik_chain_start_index[kLeftArmIK+j]];
        key_transforms[kLeftArmKey+j] = rigged_object.GetFrameMatrix(bone) * skeleton_bind_transforms[bone];
    }
    {
        int bone = ik_chain_elements[ik_chain_start_index[kTorsoIK]];
        key_transforms[kChestKey] = rigged_object.GetFrameMatrix(bone) * skeleton_bind_transforms[bone];
        bone = ik_chain_elements[ik_chain_start_index[kTorsoIK]+2];
        key_transforms[kHipKey] = rigged_object.GetFrameMatrix(bone) * skeleton_bind_transforms[bone];
    }
    {
        int bone = ik_chain_elements[ik_chain_start_index[kHeadIK]];
        key_transforms[kHeadKey] = rigged_object.GetFrameMatrix(bone) * skeleton_bind_transforms[bone];
    }

    /*int left_arm_bone = ik_chain_elements[ik_chain_start_index[kLeftArmIK]];
    int right_arm_bone = ik_chain_elements[ik_chain_start_index[kRightArmIK]];
    //BoneTransform rel_hand_transform = invert(rigged_object.GetFrameMatrix(right_arm_bone)) * rigged_object.GetFrameMatrix(left_arm_bone);
    BoneTransform rel_hand_transform = (invert(key_transforms[kRightArmKey] * inv_skeleton_bind_transforms[right_arm_bone])) * (key_transforms[kLeftArmKey] * invert(skeleton_bind_transforms[left_arm_bone]));
    //rel_hand_transform = key_transforms[kLeftArmKey];//rel_hand_transform * (key_transforms[kRightArmKey] * inv_skeleton_bind_transforms[right_arm_bone]) * skeleton_bind_transforms[left_arm_bone];
*/
    // Get initial length of each leg (in pose)
    target_leg_length.resize(2);
    for(int j=0; j<2; ++j){
        int bone = ik_chain_elements[ik_chain_start_index[kLeftLegIK+j]];
        int bone_len = ik_chain_length[kLeftLegIK+j];
        vec3 foot = key_transforms[kLeftLegKey+j] * skeleton.GetPointPos(skeleton.GetBonePoint(bone, 0));
        bone = ik_chain_elements[ik_chain_start_index[kLeftLegIK+j]+bone_len-1];
        vec3 hip = key_transforms[kHipKey] * skeleton.GetPointPos(skeleton.GetBonePoint(bone, 0));
        target_leg_length[j] = distance(hip, foot);
    }

    vec3 original_com = GetCenterOfMassEstimate(key_transforms);

    float torso_damping = 0.93f;
    float torso_stiffness = 0.5f;
    float head_damping = 0.9f;
    float head_stiffness = 0.8f;
    float head_turn_speed = 1.0f;

    float idle_look_amount = 0.0f;
    if(!this_mo.controlled && idle_type != _combat){
        idle_look_amount = idle_stance_amount*(sin(time)*0.02f+0.98f);
    }
    torso_damping = mix(torso_damping, 0.99f, idle_look_amount);
    torso_stiffness = mix(torso_stiffness, 0.03f, idle_look_amount);

    head_damping = mix(head_damping, 0.9f, idle_look_amount);
    head_stiffness = mix(head_stiffness, 1.0f, idle_look_amount);
    float head_accel_inertia = mix(0.0f, 0.99f, idle_look_amount);
    float head_accel_damping = mix(0.0f, 0.95f, idle_look_amount);
    head_turn_speed = mix(head_turn_speed, 0.0f, idle_look_amount);

    float angle_threshold = 2.2f;

    float chest_tilt_offset = 0.0f;
    float head_tilt_offset = -0.2f;
    // Rotate chest to look at target
    const bool chest_enabled = true;
    if(chest_enabled){
        EnterTelemetryZone("chest ik");
        float head_look_amount = length(torso_look);
        //vec3 tilt_axis = normalize(cross(vec3(0.0f, 1.0f, 0.0f), tilt));
        //quaternion tilt_rotate(vec4(tilt_axis.x, tilt_axis.y, tilt_axis.z, length(tilt)/180.0f*3.1417f));
        vec3 head_dir = normalize(key_transforms[kChestKey].rotation * vec3(0,0,1));//Mult(tilt_rotate, this_mo.GetFacing());
        vec3 head_up = normalize(key_transforms[kChestKey].rotation * vec3(0,1,0));//Mult(tilt_rotate, vec3(0.0f,1.0f,0.0f));
        vec3 head_right = cross(head_dir, head_up);
        
        {
            vec2 head_look_flat;
            head_look_flat.x = dot(old_chest_facing, head_right);
            head_look_flat.y = dot(old_chest_facing, head_dir);
            if(!(abs(dot(normalize(old_chest_facing), head_up)) > 0.9f)){
                old_chest_angle_vec.x = atan2(-head_look_flat.x, head_look_flat.y);
            }
            float head_up_val = dot(old_chest_facing, head_up);
            old_chest_angle_vec.y = 0.0f;
            old_chest_angle_vec.y = asin(dot(old_chest_facing, head_up));
            if(old_chest_angle_vec.y != old_chest_angle_vec.y){
                old_chest_angle_vec.y = 0.0f;
            }

            old_chest_facing = head_dir;
        }

        vec2 head_look_flat;
        head_look_flat.x = dot(torso_look, head_right);
        head_look_flat.y = dot(torso_look, head_dir);
        float angle = atan2(-head_look_flat.x, head_look_flat.y);
        if(abs(dot(normalize(torso_look), head_up)) > 0.9f){
            angle = old_chest_angle;
        }
        float head_up_val = dot(torso_look, head_up);
        float angle2 = 0.0f;
        angle2 = asin(dot(torso_look, head_up)+chest_tilt_offset);
        if(angle2 != angle2){
            angle2 = 0.0f;
        }

        // Avoid head flip-flopping when trying to look straight back
        float head_range = 1.0f;
        if(angle > angle_threshold && old_chest_angle <= -head_range ){
            angle = -head_range;
        } else if(angle < -angle_threshold && old_chest_angle >= head_range ){
            angle = head_range;
        }

        angle = min(head_range, max(-head_range, angle));

        old_chest_angle = angle;

        target_chest_angle.x = angle * head_look_amount;
        target_chest_angle.y = idle_stance_amount * (angle2 * head_look_amount);

        float torso_shake_amount = 0.005f;
        target_chest_angle.x += RangedRandomFloat(-torso_shake_amount, torso_shake_amount);
        target_chest_angle.y += RangedRandomFloat(-torso_shake_amount, torso_shake_amount);

        chest_angle_vel *= pow(torso_damping, num_frames);
        chest_angle_vel += (target_chest_angle - chest_angle) * torso_stiffness * num_frames;
        chest_angle += chest_angle_vel * time_step * num_frames;

        int neck_bone = ik_chain_elements[ik_chain_start_index[kHeadIK]+1];
        int chest_bone = ik_chain_elements[ik_chain_start_index[kTorsoIK]];
        BoneTransform chest_frame_matrix = rigged_object.GetFrameMatrix(chest_bone);
        BoneTransform chest_bind_matrix = skeleton_bind_transforms[chest_bone];
        BoneTransform rel_mat = key_transforms[kChestKey] * invert(chest_frame_matrix * chest_bind_matrix);
        vec3 neck = rigged_object.GetTransformedBonePoint(neck_bone, 0);

        quaternion rotation(vec4(head_up.x, head_up.y, head_up.z, chest_angle.x));
        quaternion rotation2(vec4(head_right.x, head_right.y, head_right.z, chest_angle.y));
        
        quaternion identity;
        int abdomen_bone = ik_chain_elements[ik_chain_start_index[kTorsoIK]+1];
        vec3 abdomen_top = rigged_object.GetTransformedBonePoint(abdomen_bone, 1);     
        vec3 abdomen_bottom = rigged_object.GetTransformedBonePoint(abdomen_bone, 0);

        BoneTransform old_chest_transform = key_transforms[kChestKey];
        key_transforms[kChestKey] = key_transforms[kChestKey] * inv_skeleton_bind_transforms[ik_chain_elements[ik_chain_start_index[kTorsoIK]]];
        key_transforms[kChestKey].origin -= abdomen_top;
        quaternion chest_rotate = rotation*rotation2;
        key_transforms[kChestKey] = mix(chest_rotate, identity, 0.5f) * key_transforms[kChestKey];
        key_transforms[kChestKey].origin += abdomen_top;
        key_transforms[kChestKey].origin -= abdomen_bottom;
        key_transforms[kChestKey] = mix(chest_rotate, identity, 0.5f) * key_transforms[kChestKey];
        key_transforms[kChestKey].origin += abdomen_bottom;
        key_transforms[kChestKey] = key_transforms[kChestKey] * skeleton_bind_transforms[ik_chain_elements[ik_chain_start_index[kTorsoIK]]];
        BoneTransform offset = key_transforms[kChestKey] * invert(old_chest_transform);
        key_transforms[kLeftArmKey] = offset * key_transforms[kLeftArmKey];
        key_transforms[kRightArmKey] = offset * key_transforms[kRightArmKey];
        key_transforms[kHeadKey] = offset * key_transforms[kHeadKey];
        LeaveTelemetryZone();
    }
    // Rotate head to look at target
    {
        EnterTelemetryZone("head ik");
        vec3 head_dir = key_transforms[kHeadKey].rotation * vec3(0,0,1);
        vec3 head_up = key_transforms[kHeadKey].rotation * vec3(0,1,0);
        vec3 head_right = cross(head_dir, head_up);

        {
            vec2 head_look_flat;
            head_look_flat.x = dot(old_head_facing, head_right);
            head_look_flat.y = dot(old_head_facing, head_dir);
            if(!(abs(dot(normalize(old_head_facing), head_up)) > 0.9f)){
                old_angle.x = atan2(-head_look_flat.x, head_look_flat.y);
            }
            float head_up_val = dot(old_head_facing, head_up);
            old_angle.y = 0.0f;
            old_angle.y = asin(dot(old_head_facing, head_up));
            if(old_angle.y != old_angle.y){
                old_angle.y = 0.0f;
            }

            old_head_facing = head_dir;
        }

        float head_look_amount = length(head_look);
        vec2 head_look_flat;
        head_look_flat.x = dot(head_look, head_right);
        head_look_flat.y = dot(head_look, head_dir);
        float angle = atan2(-head_look_flat.x, head_look_flat.y);
        if(abs(dot(normalize(head_look), head_up)) > 0.9f){
            angle = old_head_angle;
        }
        float head_up_val = dot(head_look, head_up);
        float angle2 = 0.0f;
        angle2 = (asin(dot(head_look, head_up)) + head_tilt_offset);
        if(angle2 != angle2){
            angle2 = 0.0f;
        }

        // Avoid head flip-flopping when trying to look straight back
        float head_range = 1.7f;
        if(angle > angle_threshold && old_head_angle <= -head_range ){
            angle = -head_range;
        } else if(angle < -angle_threshold && old_head_angle >= head_range ){
            angle = head_range;
        }
        angle = min(head_range, max(-head_range, angle));
        angle2 = min(0.8f, max(-0.8f, angle2));

        //angle = 0.0f;
        //angle2 = 0.0f;

        old_head_angle = angle;

        target_head_angle.x = angle * head_look_amount;
        target_head_angle.y = angle2 * head_look_amount;

        float head_shake_amount = 0.001f;
        target_head_angle.x += RangedRandomFloat(-head_shake_amount, head_shake_amount);
        target_head_angle.y += RangedRandomFloat(-head_shake_amount, head_shake_amount);

        head_angle_vel *= pow(head_damping, num_frames);
        head_angle_accel *= pow(head_accel_damping, num_frames);
        head_angle_accel = mix((target_head_angle - head_angle) * head_stiffness, head_angle_accel, pow(head_accel_inertia, num_frames));
        head_angle_vel += head_angle_accel * num_frames;
        head_angle += head_angle_vel * time_step * num_frames;
        
        
        vec2 old_offset(old_angle * (1.0f - flip_ik_fade));
        if((head_angle.x > target_head_angle.x && old_offset.x < 0.0f) ||
           (head_angle.x < target_head_angle.x && old_offset.x > 0.0f))
        {
            head_angle.x = MoveTowards(head_angle.x, target_head_angle.x, abs(old_offset.x));
        }
        if((head_angle.y > target_head_angle.x && old_offset.y < 0.0f) ||
           (head_angle.y < target_head_angle.x && old_offset.y > 0.0f))
        {
            head_angle.y = MoveTowards(head_angle.y, target_head_angle.y, abs(old_offset.y));
        }

        //head_angle.x = MoveTowards(head_angle.x, target_head_angle.x, time_step*num_frames*head_turn_speed);
        //head_angle.y = MoveTowards(head_angle.y, target_head_angle.y, time_step*num_frames*head_turn_speed);

        int neck_bone = ik_chain_elements[ik_chain_start_index[kHeadIK]+1];
        int chest_bone = ik_chain_elements[ik_chain_start_index[kTorsoIK]];
        BoneTransform chest_frame_matrix = rigged_object.GetFrameMatrix(chest_bone);
        BoneTransform chest_bind_matrix = skeleton_bind_transforms[chest_bone];
        BoneTransform rel_mat = key_transforms[kChestKey] * invert(chest_frame_matrix * chest_bind_matrix);
        vec3 neck = rel_mat * rigged_object.GetTransformedBonePoint(neck_bone, 0);

        quaternion rotation(vec4(head_up.x, head_up.y, head_up.z, head_angle.x));
        quaternion rotation2(vec4(head_right.x, head_right.y, head_right.z, head_angle.y));
        quaternion combined_rotation = rotation * rotation2;

        quaternion identity;
        key_transforms[kHeadKey] = key_transforms[kHeadKey] * inv_skeleton_bind_transforms[ik_chain_elements[ik_chain_start_index[kHeadIK]]];
        BoneTransform neck_mat = rel_mat * rigged_object.GetFrameMatrix(neck_bone);
        //neck_mat.SetTranslationPart(neck_mat.GetTranslationPart() - neck);
        neck_mat = mix(combined_rotation, identity, 0.5f) * neck_mat;
        //neck_mat.SetTranslationPart(neck_mat.GetTranslationPart() + neck);
        rigged_object.SetFrameMatrix(neck_bone, neck_mat);
        key_transforms[kHeadKey].origin -= neck;
        key_transforms[kHeadKey] = mix(combined_rotation, identity, 0.5f) * key_transforms[kHeadKey];
        key_transforms[kHeadKey].rotation = mix(combined_rotation, identity, 0.5f) * key_transforms[kHeadKey].rotation;
        key_transforms[kHeadKey].origin += neck;
        key_transforms[kHeadKey] = key_transforms[kHeadKey] * skeleton_bind_transforms[ik_chain_elements[ik_chain_start_index[kHeadIK]]];
        LeaveTelemetryZone();
    }
    
    vec3 post_look_com = GetCenterOfMassEstimate(key_transforms);

    // Compensate for COM shift caused by look
    if(on_ground) {
        //vec3 balance_offset = original_com - post_look_com;
        vec3 balance_offset = original_com - post_look_com;
        balance_offset.y = 0.0f;
        key_transforms[kHeadKey].origin += balance_offset;
        key_transforms[kChestKey].origin += balance_offset;
        key_transforms[kHipKey].origin += balance_offset;
        key_transforms[kLeftArmKey].origin += balance_offset;
        key_transforms[kRightArmKey].origin += balance_offset;
    }
    
    // Modify key transforms
    old_foot_offset.resize(2);
    old_foot_rotate.resize(2);
    if(on_ground) { // Use IK for foot plant on ground
        EnterTelemetryZone("foot ik");
        array<bool> ground_collision;
        array<vec3> offset;
        ground_collision.push_back(false);
        ground_collision.push_back(false);
        offset.resize(2);
        for(int j=0; j<2; ++j){
            // Get initial foot information
            string ik_label = j==0?"left_leg":"right_leg";
            BoneTransform mat = local_to_world * rigged_object.GetIKTransform(ik_label) * skeleton_bind_transforms[ik_chain_elements[ik_chain_start_index[kLeftLegIK+j]]];
            int bone = skeleton.IKBoneStart(ik_label);
            float weight = rigged_object.GetIKWeight(ik_label);
            vec3 anim_pos = rigged_object.GetUnmodifiedIKTransform(ik_label).GetTranslationPart();
            weight *= (1.0f-roll_ik_fade);
            if(weight > 0.0f){
                vec3 foot_center = (skeleton.GetPointPos(skeleton.GetBonePoint(bone, 0)) +
                                    skeleton.GetPointPos(skeleton.GetBonePoint(bone, 1))) * 0.5f;
                
                BoneTransform transform = mix(key_transforms[kLeftLegKey+j], mat, weight);
                vec3 pos = mat * foot_center;
                vec3 check_pos = pos + foot[j].pos;

                // Check where ground is under foot
                col.GetSweptSphereCollision(check_pos + vec3(0.0f,0.2f,0.0f),
                                            check_pos + vec3(0.0f,-0.6f,0.0f),
                                            0.05f);
                if(sphere_col.NumContacts() > 0){
                    ground_collision[j] = true;
                    float ground_height = sphere_col.position.y - 0.01;
                    if(old_foot_offset[j] != 0.0f){
                        old_foot_offset[j] = min(ground_height + 0.1f, max(ground_height - 0.1f, old_foot_offset[j]));
                        ground_height = mix(ground_height, old_foot_offset[j], pow(0.8, num_frames));
                    }
                    old_foot_offset[j] = ground_height;
                    float ground_offset = ground_height - pos.y;
                    vec3 new_pos = pos + vec3(0,ground_offset,0);
                    new_pos.y += anim_pos.y- 0.05f;
                    new_pos.y += foot[j].height;
                    new_pos.x += foot[j].pos.x;
                    new_pos.z += foot[j].pos.z;
                    offset[j] = (new_pos - pos)*weight;
                    transform.origin += offset[j];
                }

                // Check ground normal
                col.GetSlidingSphereCollision(sphere_col.position + vec3(0.0f, -0.01f, 0.0f), 0.05f);
                vec3 normal = normalize(sphere_col.adjusted_position - sphere_col.position);

                float rotate_weight = 1.0f;
                rotate_weight -= (anim_pos.y - 0.05f)*4.0f;
                rotate_weight = max(0.0f, rotate_weight);

                quaternion rotation;
                GetRotationBetweenVectors(vec3(0.0f, 1.0f, 0.0f), normal, rotation);
                rotation = mix(rotation, old_foot_rotate[j], pow(0.8, num_frames));
                old_foot_rotate[j] = rotation;
                quaternion identity;
                rotation = mix(identity, rotation, weight*rotate_weight);

                transform = transform * inv_skeleton_bind_transforms[bone];
                transform.rotation = rotation * transform.rotation;
                transform = transform * skeleton_bind_transforms[bone];
                key_transforms[kLeftLegKey+j] = transform;
            }
        }
        for(int i=0; i<2; ++i){
            int other = (i+1)%2;
            if(ground_collision[i] && !ground_collision[other]){
                key_transforms[kLeftLegKey+other].origin += offset[i];
            }
        }
        LeaveTelemetryZone();
    } else {
        for(int i=0; i<2; ++i){
            old_foot_offset[i] = 0.0f;
            old_foot_rotate[i] = quaternion();
        }
    }
    for(int j=0; j<2; ++j){
        BoneTransform mat = local_to_world * rigged_object.GetIKTransform(j==0?"leftarm":"rightarm");
        int bone = skeleton.IKBoneStart(j==0?"leftarm":"rightarm");
        float weight = rigged_object.GetIKWeight(j==0?"leftarm":"rightarm");
        weight = min(1.0f, max(0.0f, weight));
        weight *= (1.0f-roll_ik_fade);
        if(weight > 0.0f){
            mat = mat * skeleton_bind_transforms[skeleton.IKBoneStart(j==0?"leftarm":"rightarm")];
            key_transforms[kLeftArmKey+j] = mix(key_transforms[kLeftArmKey+j], mat, weight);
        }
    }

    if(ledge_info.on_ledge){
        array<vec3> hand, foot;
        vec3 body;
        hand.resize(2);
        foot.resize(2);
        ledge_info.shimmy_anim.GetIKOffsets(ledge_info.pls, body, hand[0], hand[1], foot[0], foot[1]);
        key_transforms[kHipKey].origin += body;
        key_transforms[kChestKey].origin += body;
        key_transforms[kHeadKey].origin += body;
        for(int i=0; i<2; ++i){
            key_transforms[kLeftLegKey+i].origin += foot[i];
            key_transforms[kLeftArmKey+i].origin += hand[i];
        }
    }

    // Adjust hip to preserve leg length
    BoneTransform hip_offset;
    quaternion hip_rotate;
    {
        EnterTelemetryZone("hip ik");
        array<vec3> temp_foot_pos;
        array<vec3> hip_pos;
        array<vec3> orig_hip_pos;
        temp_foot_pos.resize(2);
        hip_pos.resize(2);
        orig_hip_pos.resize(2);
        for(int j=0; j<2; ++j){
            int bone = ik_chain_start_index[kLeftLegIK+j];
            int bone_len = ik_chain_length[kLeftLegIK+j];;
            temp_foot_pos[j] = key_transforms[kLeftLegKey+j] * skeleton.GetPointPos(skeleton.GetBonePoint(ik_chain_elements[bone], 0));
            hip_pos[j] = key_transforms[kHipKey] * skeleton.GetPointPos(skeleton.GetBonePoint(ik_chain_elements[bone+bone_len-1], 0));    
            orig_hip_pos[j] = hip_pos[j];
        }
        vec3 orig_mid = (orig_hip_pos[0] + orig_hip_pos[1])*0.5f;
        for(int i=0; i<2; ++i){
            float hip_dist = distance(hip_pos[0], hip_pos[1]);
            for(int j=0; j<2; ++j){
                hip_pos[j] = temp_foot_pos[j] + normalize(hip_pos[j]-temp_foot_pos[j])*target_leg_length[j];
            }
            vec3 mid = (hip_pos[0] + hip_pos[1])*0.5f;
            mid = vec3(orig_mid.x, mid.y, orig_mid.z);
            vec3 dir = normalize((hip_pos[1]-hip_pos[0])+(orig_hip_pos[1]-orig_hip_pos[0])*3.0f);
            hip_pos[0] = mid + dir * hip_dist * -0.5f;
            hip_pos[1] = mid + dir * hip_dist * 0.5f;
        }
        quaternion rotation;
        {
            vec3 orig_hip_vec = normalize(orig_hip_pos[1] - orig_hip_pos[0]);
            vec3 new_hip_vec = normalize(hip_pos[1]-hip_pos[0]);
            vec3 rotate_axis = normalize(cross(orig_hip_vec, new_hip_vec));
            vec3 right_vec = cross(orig_hip_vec, rotate_axis);
            float rotate_angle = atan2(-dot(new_hip_vec, right_vec), dot(new_hip_vec, orig_hip_vec));
            float flat_speed = sqrt(this_mo.velocity.x*this_mo.velocity.x + this_mo.velocity.z*this_mo.velocity.z);
            float max_rotate_angle = max(0.0f, 0.2f - flat_speed * 0.2f);
            rotate_angle = max(-max_rotate_angle, min(max_rotate_angle, rotate_angle));
            rotation = quaternion(vec4(rotate_axis, rotate_angle));
        }
        hip_rotate = rotation;
        int hip_bone = skeleton.IKBoneStart("torso");
        int hip_bone_len = skeleton.IKBoneLength("torso");
        for(int i=0; i<hip_bone_len-1; ++i){
            hip_bone = skeleton.GetParent(hip_bone);
        }
        vec3 hip_root = key_transforms[kHipKey] * ((skeleton.GetPointPos(skeleton.GetBonePoint(hip_bone, 1))));// + skeleton.GetPointPos(skeleton.GetBonePoint(hip_bone, 1))) * 0.5f);
        vec3 orig_hip_offset = (orig_hip_pos[0] + orig_hip_pos[1])*0.5f - hip_root;
        hip_offset.origin = (hip_pos[0]+hip_pos[1])*0.5f-(orig_hip_pos[0] + orig_hip_pos[1])*0.5f+orig_hip_offset-hip_rotate*orig_hip_offset;
        vec3 temp = hip_offset.origin;
        if(old_hip_offset == vec3(0.0f)){
            old_hip_offset = temp;
        }
        hip_offset.origin = mix(temp, old_hip_offset, pow(0.95f,num_frames));
        old_hip_offset = hip_offset.origin;
        LeaveTelemetryZone();
    } 
    vec3 body_offset(0.0f);
    bool idle_bob_enabled = false;
    if(idle_bob_enabled && idle_stance_amount > 0.0f){
        float body_bob_time = time + body_bob_time_offset;
        body_offset.y = sin(body_bob_time*4.0f*body_bob_freq)*0.02f*idle_stance_amount;
        body_offset.x = sin(body_bob_time*2.0f*body_bob_freq)*0.02f*idle_stance_amount;
        body_offset.z = sin(body_bob_time*1.5f*body_bob_freq)*0.02f*idle_stance_amount;
    }
    if(idle_stance_amount > 0.0f){
        vec3 left_foot = (key_transforms[kLeftLegKey]*inv_skeleton_bind_transforms[ik_chain_elements[ik_chain_start_index[kLeftLegIK]]]).origin;
        vec3 right_foot = (key_transforms[kRightLegKey]*inv_skeleton_bind_transforms[ik_chain_elements[ik_chain_start_index[kRightLegIK]]]).origin;
        if(last_changed_com < time){
            last_changed_com = time + RangedRandomFloat(0.7f,4.0f);
            target_com_offset.x = RangedRandomFloat(-0.05f,0.05f);
            target_com_offset.y = RangedRandomFloat(-0.005f,0.005f) * this_mo.rigged_object().GetCharScale();
            target_com_offset.z = RangedRandomFloat(-0.01f,0.01f) * this_mo.rigged_object().GetCharScale();
        }
        //DebugText("com_offset", "com_offset: "+com_offset, 0.5f);
        com_offset_vel *= 0.97f;
        com_offset_vel += (target_com_offset - com_offset) * 5.0f * time_step * num_frames;
        com_offset += com_offset_vel * time_step * num_frames;
        vec3 target_com = (right_foot - left_foot) * com_offset.x + this_mo.GetFacing() * com_offset.z;
        body_offset.x += target_com.x * idle_stance_amount;
        body_offset.z += target_com.z * idle_stance_amount;
        body_offset.y += com_offset.y * idle_stance_amount;

        vec3 axis = right_foot - left_foot;
        axis = vec3(axis.z, 0.0f, -axis.x);
        axis = normalize(axis);
        quaternion rotate_x(vec4(axis.x, axis.y, axis.z, com_offset.x*0.25f*idle_stance_amount));
        key_transforms[kChestKey].rotation = rotate_x * key_transforms[kChestKey].rotation;
        key_transforms[kHipKey].rotation = rotate_x * key_transforms[kHipKey].rotation;
        key_transforms[kHeadKey].origin -= key_transforms[kChestKey].origin;
        key_transforms[kHeadKey] = rotate_x * key_transforms[kHeadKey];
        key_transforms[kHeadKey].origin += key_transforms[kChestKey].origin;
    } else {
        com_offset = 0.0f;
        target_com_offset = com_offset;
        com_offset_vel = 0.0f;
    }
    
    hip_offset.origin += body_offset;// * this_mo.rigged_object().GetCharScale() );
    
    if(!ledge_info.on_ledge){
        key_transforms[kChestKey] = hip_offset * key_transforms[kChestKey];
        key_transforms[kHeadKey] = hip_offset * key_transforms[kHeadKey];
        key_transforms[kHipKey] = hip_offset * key_transforms[kHipKey];
        key_transforms[kHipKey].rotation = hip_rotate * key_transforms[kHipKey].rotation;
        key_transforms[kLeftArmKey] = hip_offset * key_transforms[kLeftArmKey];
        key_transforms[kRightArmKey] = hip_offset * key_transforms[kRightArmKey];
    }    
    // Adjust arms for dragging bodies
    if(tethered == _TETHERED_DRAGBODY){
        MovementObject@ char = ReadCharacterID(tether_id);
        vec3 target = char.rigged_object().GetIKChainPos(drag_body_part,drag_body_part_id);

        vec3 offset;
        if(weapon_slots[_held_left] != -1 || weapon_slots[_held_right] != -1){
            if(weapon_slots[_held_left] == -1){
                offset = target - key_transforms[kLeftArmKey] * skeleton.GetPointPos(skeleton.GetBonePoint(skeleton.IKBoneStart("leftarm"), 0));
            } else if(weapon_slots[_held_right] == -1){
                offset = target - key_transforms[kRightArmKey] * skeleton.GetPointPos(skeleton.GetBonePoint(skeleton.IKBoneStart("rightarm"), 0));
            } 
            offset.y += 0.1f;
            vec3 facing = this_mo.GetFacing();
            vec3 right = vec3(facing.z, 0.0f, -facing.x);
            if(weapon_slots[_held_left] == -1){
                offset += right * 0.05f;
            } else if(weapon_slots[_held_right] == -1){
                offset -= right * 0.05f;
            } 
        } else {
            vec3 hand_mid = (key_transforms[kLeftArmKey] * skeleton.GetPointPos(skeleton.GetBonePoint(skeleton.IKBoneStart("leftarm"), 0)) +
                             key_transforms[kRightArmKey] * skeleton.GetPointPos(skeleton.GetBonePoint(skeleton.IKBoneStart("rightarm"), 0))) * 0.5f;
            offset = target - hand_mid;
        }
        if(offset.y < -0.05f){
            offset.y = -0.05f;
        }

        if(weapon_slots[_held_left] == -1){
            key_transforms[kLeftArmKey].origin += offset * drag_strength_mult;
        }
        if(weapon_slots[_held_right] == -1){
            key_transforms[kRightArmKey].origin += offset * drag_strength_mult;
        }
    }

    vec3 final_com = GetCenterOfMassEstimate(key_transforms);

    // Compensate for COM shift in air
    if(!on_ground && !ledge_info.on_ledge) {
        vec3 balance_offset = original_com - final_com;
        key_transforms[kHeadKey].origin += balance_offset;
        key_transforms[kChestKey].origin += balance_offset;
        key_transforms[kHipKey].origin += balance_offset;
        key_transforms[kLeftArmKey].origin += balance_offset;
        key_transforms[kRightArmKey].origin += balance_offset;
        key_transforms[kLeftLegKey].origin += balance_offset;
        key_transforms[kRightLegKey].origin += balance_offset;
    }

    quaternion test_rot(vec4(1,0,0,sin(time)));
    BoneTransform old_chest_transform = key_transforms[kChestKey];
    //key_transforms[kChestKey].SetRotationPart(Mat4FromQuaternion(test_rot) * key_transforms[kChestKey].GetRotationPart());
    //key_transforms[kLeftArmKey].SetTranslationPart(key_transforms[kLeftArmKey].GetTranslationPart() + vec3(sin(time)*0.5f,0.0f, 0.0f));

    const bool draw_key_points = false;
    if(draw_key_points){
        array<vec3> points;
        points.resize(4);
        // Draw leg transforms
        for(int j=0; j<2; ++j){
            int bone;
            mat4 transform = key_transforms[kLeftLegKey+j].GetMat4();
            if(j==0){
                bone = skeleton.IKBoneStart("left_leg");
            } else {
                bone = skeleton.IKBoneStart("right_leg");
            }
            vec3 foot_center = skeleton.GetPointPos(skeleton.GetBonePoint(bone, 0)) +
                               skeleton.GetPointPos(skeleton.GetBonePoint(bone, 1));
            foot_center *= 0.5f;
            float foot_vis_size = 0.1f;
            points[0] = transform * (foot_center + vec3(0.0f,0.0f,foot_vis_size));
            points[1] = transform * (foot_center + vec3(foot_vis_size,0.0f,0.0f));
            points[2] = transform * (foot_center + vec3(0.0f,0.0f,-foot_vis_size));
            points[3] = transform * (foot_center + vec3(-foot_vis_size,0.0f,0.0f));
            for(int i=0; i<4; ++i){
                debug_lines.push_back(DebugDrawLine(points[i], points[(i+1)%4], vec3(0.0f,1.0f,0.0f), _fade));
            }
        }
        // Draw hand transforms
        for(int j=0; j<2; ++j){
            int bone;
            if(j==0){
                bone = skeleton.IKBoneStart("leftarm");
            } else {
                bone = skeleton.IKBoneStart("rightarm");
            }
            mat4 transform = key_transforms[kLeftArmKey+j].GetMat4();
            vec3 foot_center = skeleton.GetPointPos(skeleton.GetBonePoint(bone, 0)) +
                               skeleton.GetPointPos(skeleton.GetBonePoint(bone, 1));
            foot_center *= 0.5f;
            float foot_vis_size = 0.1f;
            points[0] = transform * (foot_center + vec3(0.0f,0.0f,foot_vis_size));
            points[1] = transform * (foot_center + vec3(foot_vis_size,0.0f,0.0f));
            points[2] = transform * (foot_center + vec3(0.0f,0.0f,-foot_vis_size));
            points[3] = transform * (foot_center + vec3(-foot_vis_size,0.0f,0.0f));
            for(int i=0; i<4; ++i){
                debug_lines.push_back(DebugDrawLine(points[i], points[(i+1)%4], vec3(0.0f,1.0f,0.0f), _fade));
            }
        }
        // Draw chest transform
        {
            int bone = skeleton.IKBoneStart("torso");
            mat4 transform = key_transforms[kChestKey].GetMat4();
            vec3 foot_center = skeleton.GetPointPos(skeleton.GetBonePoint(bone, 0)) +
                               skeleton.GetPointPos(skeleton.GetBonePoint(bone, 1));
            foot_center *= 0.5f;
            float chest_vis_size = 0.125f;
            points[0] = transform * (foot_center + vec3(0.0f,0.0f,chest_vis_size));
            points[1] = transform * (foot_center + vec3(chest_vis_size,0.0f,0.0f));
            points[2] = transform * (foot_center + vec3(0.0f,0.0f,-chest_vis_size));
            points[3] = transform * (foot_center + vec3(-chest_vis_size,0.0f,0.0f));
            for(int i=0; i<4; ++i){
                debug_lines.push_back(DebugDrawLine(points[i], points[(i+1)%4], vec3(0.0f,1.0f,0.0f), _fade));
            }
        }
        // Draw hip transform
        {
            int bone = skeleton.IKBoneStart("torso");
            bone = skeleton.GetParent(bone);
            bone = skeleton.GetParent(bone);
            mat4 transform = key_transforms[kHipKey].GetMat4();
            vec3 foot_center = skeleton.GetPointPos(skeleton.GetBonePoint(bone, 0)) +
                               skeleton.GetPointPos(skeleton.GetBonePoint(bone, 1));
            foot_center *= 0.5f;
            float chest_vis_size = 0.125f;
            points[0] = transform * (foot_center + vec3(0.0f,0.0f,chest_vis_size));
            points[1] = transform * (foot_center + vec3(chest_vis_size,0.0f,0.0f));
            points[2] = transform * (foot_center + vec3(0.0f,0.0f,-chest_vis_size));
            points[3] = transform * (foot_center + vec3(-chest_vis_size,0.0f,0.0f));
            for(int i=0; i<4; ++i){
                debug_lines.push_back(DebugDrawLine(points[i], points[(i+1)%4], vec3(0.0f,1.0f,0.0f), _fade));
            }
        }
        // Draw head transform
        {
            int bone = skeleton.IKBoneStart("head");
            mat4 transform = key_transforms[kHeadKey].GetMat4();
            vec3 foot_center = skeleton.GetPointPos(skeleton.GetBonePoint(bone, 0)) +
                               skeleton.GetPointPos(skeleton.GetBonePoint(bone, 1));
            foot_center *= 0.5f;
            float chest_vis_size = 0.1f;
            points[0] = transform * (foot_center + vec3(0.0f,0.0f,chest_vis_size));
            points[1] = transform * (foot_center + vec3(chest_vis_size,0.0f,0.0f));
            points[2] = transform * (foot_center + vec3(0.0f,0.0f,-chest_vis_size*0.1f));
            points[3] = transform * (foot_center + vec3(-chest_vis_size,0.0f,0.0f));
            for(int i=0; i<4; ++i){
                debug_lines.push_back(DebugDrawLine(points[i], points[(i+1)%4], vec3(0.0f,1.0f,0.0f), _fade));
            }
        }
    }

    //key_transforms[kLeftArmKey] = (key_transforms[kRightArmKey] * inv_skeleton_bind_transforms[right_arm_bone]) * rel_hand_transform * skeleton_bind_transforms[left_arm_bone];
    
    EnterTelemetryZone("final bone ik");
    DrawLeg(false, key_transforms[kHipKey], key_transforms[kLeftLegKey], num_frames);
    DrawLeg(true, key_transforms[kHipKey], key_transforms[kRightLegKey], num_frames);

    /*quaternion weap_rotation;
    vec3 weap_old_mid;
    vec3 weap_new_mid;    
    DrawWeapon(num_frames, weap_rotation, weap_old_mid, weap_new_mid);
    for(int i=0; i<2; ++i){
        key_transforms[kLeftArmKey+i].origin -= weap_old_mid;
        key_transforms[kLeftArmKey+i] = weap_rotation * key_transforms[kLeftArmKey+i];
        key_transforms[kLeftArmKey+i].origin += weap_new_mid;
    }*/
    DrawArms(key_transforms[kChestKey], key_transforms[kLeftArmKey], key_transforms[kRightArmKey], num_frames);

    DrawHead(key_transforms[kChestKey], key_transforms[kHeadKey], num_frames);
    
    DrawBody(key_transforms[kHipKey], key_transforms[kChestKey]);
    
    DrawEar(false, key_transforms[kHeadKey], num_frames);
    DrawEar(true, key_transforms[kHeadKey], num_frames);
    
    DrawTail(num_frames);
    LeaveTelemetryZone();

    // Get center of mass
    const bool draw_com = false;
    if(draw_com){
        vec3 frame_com = rigged_object.GetFrameCenterOfMass();
        debug_lines.push_back(DebugDrawWireSphere(frame_com, 0.1f, vec3(1.0f), _fade));
        debug_lines.push_back(DebugDrawLine(frame_com, frame_com+vec3(0.0f,-1.0f,0.0f), vec3(1.0f), _fade));
    }

    if(ragdoll_pose.size() > 0 && unragdoll_time > time - 1.0f/ragdoll_fade_speed){
        EnterTelemetryZone("ragdoll transition blend");
        int root;
        array<BoneTransform> rel_mats;
        array<BoneTransform> ragdoll_rel_mats;
        array<BoneTransform> blended_rel_mats;
        rel_mats.resize(skeleton.NumBones());
        ragdoll_rel_mats.resize(skeleton.NumBones());
        blended_rel_mats.resize(skeleton.NumBones());
        EnterTelemetryZone("getting relative matrices");
        for(int i=0, len=skeleton.NumBones(); i<len; ++i){
            ragdoll_pose[i].SetTranslationPart(ragdoll_pose[i].GetTranslationPart() + this_mo.velocity * time_step * num_frames);
            int parent = skeleton.GetParent(i);
            if(parent != -1){
                rel_mats[i] = invert(BoneTransform(rigged_object.GetFrameMatrix(parent))) * BoneTransform(rigged_object.GetFrameMatrix(i));
                ragdoll_rel_mats[i] = invert(BoneTransform(ragdoll_pose[parent])) * BoneTransform(ragdoll_pose[i]);
            } else {
                rel_mats[i] = BoneTransform(rigged_object.GetFrameMatrix(i));
                ragdoll_rel_mats[i] = BoneTransform(ragdoll_pose[i]);
                root = i;
            }
        }
        LeaveTelemetryZone();

        EnterTelemetryZone("blending matrices");
        for(int i=0, len=skeleton.NumBones(); i<len; ++i){
            blended_rel_mats[i] = mix(ragdoll_rel_mats[i], rel_mats[i], (time - unragdoll_time)*ragdoll_fade_speed);
        }
        LeaveTelemetryZone();

        EnterTelemetryZone("Applying parent rotations");
        for(int i=0, len=skeleton.NumBones(); i<len; ++i){
            ragdoll_pose[i] = skeleton.ApplyParentRotations(blended_rel_mats, i).GetMat4();
            rigged_object.SetFrameMatrix(i, skeleton.ApplyParentRotations(blended_rel_mats, i));
        }
        LeaveTelemetryZone();
        LeaveTelemetryZone();
    }

    UpdateEyeLook();
    LeaveTelemetryZone();
}

void ApplyPhysics(const Timestep &in ts) {
    if(!on_ground){
        this_mo.velocity += physics.gravity_vector * ts.step();
    }
    if(on_ground){
        //Print("Friction "+friction+"\n");
        if(!feet_moving){
            this_mo.velocity *= pow(0.95f,ts.frames());
        } else {
            const float e = 2.71828183f;
            float exp = _walk_accel*time_step*-1/max_speed;
            float current_movement_friction = pow(e,exp);
            this_mo.velocity *= pow(current_movement_friction, ts.frames());
        }
    }
}

void SetParameters() {
    params.AddIntSlider("Lives",1,"min:1,max:4");
    p_lives = max(1, params.GetInt("Lives"));
    lives = p_lives;

    params.AddFloatSlider("Aggression",0.5,"min:0,max:1,step:0.1,text_mult:100");
    p_aggression = min(1.0f, max(0.0f, params.GetFloat("Aggression")));

    params.AddFloatSlider("Damage Resistance",1,"min:0,max:2,step:0.1,text_mult:100");
    p_damage_multiplier = 1.0f / max(0.00001f,params.GetFloat("Damage Resistance"));

    params.AddFloatSlider("Block Skill",0.5,"min:0,max:1,step:0.1,text_mult:100");
    p_block_skill = min(1.0f, max(0.0f, params.GetFloat("Block Skill")));

    params.AddFloatSlider("Block Follow-up",0.5,"min:0,max:1,step:0.1,text_mult:100");
    p_block_followup = min(1.0f, max(0.0f, params.GetFloat("Block Follow-up")));

    params.AddFloatSlider("Ground Aggression",0.5,"min:0,max:1,step:0.1,text_mult:100");
    p_ground_aggression = min(1.0f, max(0.0f, params.GetFloat("Ground Aggression")));

    params.AddFloatSlider("Attack Speed",1,"min:0,max:2,step:0.1,text_mult:100");
    p_attack_speed_mult = min(2.0f, max(0.1f, params.GetFloat("Attack Speed")));

    params.AddFloatSlider("Attack Damage",1,"min:0,max:2,step:0.1,text_mult:100");
    p_attack_damage_mult = max(0.0f, params.GetFloat("Attack Damage"));

    params.AddFloatSlider("Attack Knockback",1,"min:0,max:2,step:0.1,text_mult:100");
    p_attack_knockback_mult = max(0.0f, params.GetFloat("Attack Knockback"));

    params.AddFloatSlider("Movement Speed",1,"min:0.1,max:1.5,step:0.1,text_mult:100");
    p_speed_mult = min(100.0f, max(0.01f, params.GetFloat("Movement Speed")));
    run_speed = _base_run_speed * p_speed_mult;
    true_max_speed = _base_true_max_speed * p_speed_mult;
    
    params.AddIntCheckbox("Left handed",false);
    left_handed = (params.GetInt("Left handed") != 0);

    params.AddIntCheckbox("Static",false);
    static_char = (params.GetInt("Static") != 0);
    
    params.AddFloatSlider("Character Scale",1,"min:0.6,max:1.4,step:0.02,text_mult:100");
    float new_char_scale = params.GetFloat("Character Scale");
    if(new_char_scale != this_mo.rigged_object().GetRelativeCharScale()){
        this_mo.RecreateRiggedObject(this_mo.char_path);
        ResetSecondaryAnimation();
        ResetLayers();
        CacheSkeletonInfo();
    }
    
    params.AddFloatSlider("Fat",0.5f,"min:0.0,max:1.0,step:0.05,text_mult:200");
    p_fat = params.GetFloat("Fat")*2.0f-1.0f;

    params.AddFloatSlider("Muscle",0.5f,"min:0.0,max:1.0,step:0.05,text_mult:200");
    p_muscle = params.GetFloat("Muscle")*2.0f-1.0f;

    params.AddFloatSlider("Ear Size",1.0f,"min:0.0,max:3.0,step:0.1,text_mult:100");
    p_ear_size = params.GetFloat("Ear Size")*0.5f+0.5f;

    string team_str;
    character_getter.GetTeamString(team_str);
    params.AddString("Teams",team_str);

    mirrored_stance = left_handed;
    primary_weapon_slot = left_handed?_held_left:_held_right;
    secondary_weapon_slot = left_handed?_held_right:_held_left;

    if(params.HasParam("Unarmed Stance Override")){
        this_mo.OverrideCharAnim("idle", params.GetString("Unarmed Stance Override"));
    }

    ApplyBoneInflation();
}
