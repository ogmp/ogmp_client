#include "ui_effects.as"
#include "threatcheck.as"
#include "music_load.as"

bool reset_allowed = true;
float time = 0.0f;
float no_win_time = 0.0f;
string level_name;
int in_victory_trigger = 0;
const float _reset_delay = 4.0f;
float reset_timer = _reset_delay;

MusicLoad ml("Data/Music/challengelevel.xml");

void Init(string p_level_name) {
    challenge_end_gui.Init();
    level_name = p_level_name;
}

class Achievements {
    bool flawless_;
    bool no_first_strikes_;
    bool no_counter_strikes_;
    bool no_kills_;
    bool no_alert_;
    bool injured_;
    float total_block_damage_;
    float total_damage_;
    float total_blood_loss_;
    void Init() {
        flawless_ = true;
        no_first_strikes_ = true;
        no_counter_strikes_ = true;
        no_kills_ = true;
        no_alert_ = true;
        injured_ = false;
        total_block_damage_ = 0.0f;
        total_damage_ = 0.0f;
        total_blood_loss_ = 0.0f;
    }
    Achievements() {
        Init();
    }
    void UpdateDebugText() {
        DebugText("achmt0", "Flawless: "+flawless_, 0.5f);
        DebugText("achmt1", "No Injuries: "+!injured_, 0.5f);
        DebugText("achmt2", "No First Strikes: "+no_first_strikes_, 0.5f);
        DebugText("achmt3", "No Counter Strikes: "+no_counter_strikes_, 0.5f);
        DebugText("achmt4", "No Kills: "+no_kills_, 0.5f);
        DebugText("achmt5", "No Alerts: "+no_alert_, 0.5f);
        DebugText("achmt6", "Time: "+no_win_time, 0.5f);
        //DebugText("achmt_damage0", "Block damage: "+total_block_damage_, 0.5f);
        //DebugText("achmt_damage1", "Impact damage: "+total_damage_, 0.5f);
        //DebugText("achmt_damage2", "Blood loss: "+total_blood_loss_, 0.5f);

        SavedLevel @level = save_file.GetSavedLevel(level_name);
        DebugText("saved_achmt0", "Saved Flawless: "+(level.GetValue("flawless")=="true"), 0.5f);
        DebugText("saved_achmt1", "Saved No Injuries: "+(level.GetValue("no_injuries")=="true"), 0.5f);
        DebugText("saved_achmt2", "Saved No Kills: "+(level.GetValue("no_kills")=="true"), 0.5f);
        DebugText("saved_achmt3", "Saved No Alert: "+(level.GetValue("no_alert")=="true"), 0.5f);
        DebugText("saved_achmt4", "Saved Time: "+level.GetValue("time"), 0.5f);
    }
    void Save() {
        SavedLevel @saved_level = save_file.GetSavedLevel(level_name);
        if(flawless_) saved_level.SetValue("flawless","true");
        if(!injured_) saved_level.SetValue("no_injuries","true");
        if(no_kills_) saved_level.SetValue("no_kills","true");
        if(no_alert_) saved_level.SetValue("no_alert","true");
        string time_str = saved_level.GetValue("time");
        if(time_str == "" || no_win_time < atof(saved_level.GetValue("time"))){
            saved_level.SetValue("time", ""+no_win_time);
        }
        save_file.WriteInPlace();
    }
    void PlayerWasHit() {
        flawless_ = false;
    }
    void PlayerWasInjured() {
        injured_ = true;
        flawless_ = false;
    }
    void PlayerAttacked() {
        no_first_strikes_ = false;
    }
    void PlayerSneakAttacked() {
        no_first_strikes_ = false;
    }
    void PlayerCounterAttacked() {
        no_counter_strikes_ = false;
    }
    void EnemyDied() {
        no_kills_ = false;
    }
    void EnemyAlerted() {
        no_alert_ = false;
    }
    void PlayerBlockDamage(float val) {
        total_block_damage_ += val;
        PlayerWasHit();
    }
    void PlayerDamage(float val) {
        total_damage_ += val;
        PlayerWasInjured();
    }
    void PlayerBloodLoss(float val) {
        total_blood_loss_ += val;
        PlayerWasInjured();
    }
    bool GetValue(const string &in key){
        if(key == "flawless"){
            return flawless_;
        } else if(key == "no_kills"){
            return no_kills_;
        } else if(key == "no_injuries"){
            return !injured_;
        }
        return false; 
    }
};

Achievements achievements;

bool HasFocus(){
    return (challenge_end_gui.target_visible == 1.0f);
}

void Reset(){
    time = 0.0f;
    reset_allowed = true;
    reset_timer = _reset_delay;
    achievements.Init();
    challenge_end_gui.target_visible = 0.0;
}

void ReceiveMessage(string msg) {
    TokenIterator token_iter;
    token_iter.Init();
    if(!token_iter.FindNextToken(msg)){
        return;
    }
    string token = token_iter.GetToken(msg);
    if(token == "reset"){
        Reset();
    } else if(token == "dispose_level"){
        gui.RemoveAll();
    } else if(token == "achievement_event"){
        token_iter.FindNextToken(msg);
        AchievementEvent(token_iter.GetToken(msg));
    } else if(token == "achievement_event_float"){
        token_iter.FindNextToken(msg);
        string str = token_iter.GetToken(msg);
        token_iter.FindNextToken(msg);
        float val = atof(token_iter.GetToken(msg));
        AchievementEventFloat(str, val);
    } else if(token == "victory_trigger_enter"){
        ++in_victory_trigger;
        in_victory_trigger = max(1,in_victory_trigger);
    } else if(token == "victory_trigger_exit"){
        --in_victory_trigger;
    }
}

void DrawGUI() {
    challenge_end_gui.DrawGUI();
}

void AchievementEvent(string event_str){
    if(event_str == "player_was_hit"){
        achievements.PlayerWasHit();
    } else if(event_str == "player_was_injured"){
        achievements.PlayerWasInjured();
    } else if(event_str == "player_attacked"){
        achievements.PlayerAttacked();
    } else if(event_str == "player_sneak_attacked"){
        achievements.PlayerSneakAttacked();
    } else if(event_str == "player_counter_attacked"){
        achievements.PlayerCounterAttacked();
    } else if(event_str == "enemy_died"){
        achievements.EnemyDied();
    } else if(event_str == "enemy_alerted"){
        achievements.EnemyAlerted();
    }
}

void AchievementEventFloat(string event_str, float val){
    if(event_str == "player_block_damage"){
        achievements.PlayerBlockDamage(val);
    } else if(event_str == "player_damage"){
        achievements.PlayerDamage(val);
    } else if(event_str == "player_blood_loss"){
        achievements.PlayerBloodLoss(val);
    }
}

string StringFromFloatTime(float time){
    string time_str;
    int minutes = int(time) / 60;
    int seconds = int(time)-minutes*60;
    time_str += minutes + ":";
    if(seconds < 10){
        time_str += "0";
    }
    time_str += seconds;
    return time_str;
}

class ChallengeEndGUI {
    float visible;
    float target_visible;
    int gui_id;
    IMUIContext imui_context;
    RibbonBackground ribbon_background;

    void Init(){
        visible = 0.0;
        target_visible = 0.0;
        gui_id = -1;
    }

    ChallengeEndGUI() {
        imui_context.Init();
        ribbon_background.Init();
    }

    void Update(){
        visible = UpdateVisible(visible, target_visible);
        if(gui_id != -1){
            gui.MoveTo(gui_id,GetScreenWidth()/2-400,GetScreenHeight()/2-300);
        }
        if(target_visible == 1.0f){
            if(gui_id == -1){
                CreateGUI();
            }
        } else {
            if(gui_id != -1){
                gui.RemoveGUI(gui_id);
                gui_id = -1;
            }
        }
        ribbon_background.Update();
        UpdateMusic();
    }

    void CreateGUI() {
        gui_id = gui.AddGUI("text2","challengelevel/challenge.html",800,600, _GG_IGNORES_MOUSE);   

        string mission_objective;
        string mission_objective_color;
        bool success = true;

        for(int i=0; i<level.GetNumObjectives(); ++i){
            string objective = level.GetObjective(i);
            if(objective == "destroy_all"){
                int threats_possible = ThreatsPossible();
                int threats_remaining = ThreatsRemaining();
                if(threats_possible <= 0){
                    mission_objective = "  Defeat all enemies (N/A)";
                    mission_objective_color = "red";
                } else {
                    if(threats_remaining == 0){
                        mission_objective += "v ";
                        mission_objective_color = "green";
                    } else {
                        mission_objective += "x ";
                        mission_objective_color = "red";
                        success = false;
                    }
                    mission_objective += "defeat all enemies (" ;
                    mission_objective += (threats_possible - threats_remaining);
                    mission_objective += "/" ;
                    mission_objective += threats_possible;
                    mission_objective += ")";
                }
            }
            if(objective == "reach_a_trigger"){
                if(in_victory_trigger > 0){
                    mission_objective += "v ";
                    mission_objective_color = "green";
                } else {
                    mission_objective += "x ";
                    mission_objective_color = "red";
                    success = false;
                }
                mission_objective += "Reach the goal";
            }
            if(objective == "must_visit_trigger"){
                if(NumUnvisitedMustVisitTriggers() == 0){
                    mission_objective += "v ";
                    mission_objective_color = "green";
                } else {
                    mission_objective += "x ";
                    mission_objective_color = "red";
                    success = false;
                }
                mission_objective += "Visit all checkpoints";
            }
            if(objective == "reach_a_trigger_with_no_pursuers"){
                if(in_victory_trigger > 0 && NumActivelyHostileThreats() == 0){
                    mission_objective += "v ";
                    mission_objective_color = "green";
                } else {
                    mission_objective += "x ";
                    mission_objective_color = "red";
                    success = false;
                }
                mission_objective += "Reach the goal without any pursuers";
            }

            if(objective == "collect"){
                if(NumUnsatisfiedCollectableTargets() != 0){
                    success = false;
                    mission_objective += "x ";
                    mission_objective_color = "red";
                }  else {
                    mission_objective += "v ";
                    mission_objective_color = "green";
                }
                mission_objective += "Collect items";
            }
        }

        string title = success?'challenge complete':'challenge incomplete';
        gui.Execute(gui_id,"addElement('', 'title', '"+title+"')");
        gui.Execute(gui_id,"addElement('', 'hr', '')");
        gui.Execute(gui_id,"addElement('', 'spacer', '')");
        gui.Execute(gui_id,"addElement('objectives', 'heading', 'objectives:')");

        gui.Execute(gui_id,"addElement('', '"+mission_objective_color+
            "', '"+mission_objective+"', 'objectives')");
        gui.Execute(gui_id,"addElement('time', 'heading', 'time:')");
        string time_color;
        if(success){
            time_color = "green time";
        } else {
            time_color = "red time";
        }
        gui.Execute(gui_id,"addElement('', '"+time_color+"', '"+StringFromFloatTime(no_win_time)+"', 'time')");
        SavedLevel @saved_level = save_file.GetSavedLevel(level_name);
        float best_time = atof(saved_level.GetValue("time"));
        if(best_time > 0.0f){
            gui.Execute(gui_id,"addElement('', 'teal time', '"+StringFromFloatTime(best_time)+"', 'time')");
        }
        int player_id = GetPlayerCharacterID();
        if(player_id != -1){
            for(int i=0; i<level.GetNumObjectives(); ++i){
                string objective = level.GetObjective(i);
                if(objective == "destroy_all"){
                    gui.Execute(gui_id,"addElement('enemies', 'heading', 'enemies:')");
                    MovementObject@ player_char = ReadCharacter(player_id);
                    int num = GetNumCharacters();
                    for(int j=0; j<num; ++j){
                        MovementObject@ char = ReadCharacter(j);
                        if(!player_char.OnSameTeam(char)){
                            int knocked_out = char.GetIntVar("knocked_out");
                            if(knocked_out == 1 && char.GetFloatVar("blood_health") <= 0.0f){
                                knocked_out = 2;
                            }
                            switch(knocked_out){
                            case 0:    
                                gui.Execute(gui_id,"addElement('', 'ok', '', 'enemies')"); break;
                            case 1:    
                                gui.Execute(gui_id,"addElement('', 'ko', '', 'enemies')"); break;
                            case 2:    
                                gui.Execute(gui_id,"addElement('', 'dead', '', 'enemies')"); break;
                            }
                        }
                    }
                }
            }
        }
        gui.Execute(gui_id,"addElement('extra', 'heading', 'extra:')");

        int num_achievements = level.GetNumAchievements();
        for(int i=0; i<num_achievements; ++i){
            string achievement = level.GetAchievement(i);
            string display_str;
            string color_str = "red";
            if(saved_level.GetValue(achievement) == "true"){
                color_str = "teal";
            }
            if(achievements.GetValue(achievement)){
                color_str = "green";
            }
            if(achievement == "flawless"){
                display_str += "flawless";
            } else if(achievement == "no_kills"){
                display_str += "no kills";
            } else if(achievement == "no_injuries"){
                display_str = "never hurt";
            } else if(achievement == "no_alert"){
                display_str = "never seen";
            }
            gui.Execute(gui_id,"addElement('', '"+color_str+"', '"+display_str+"', 'extra')");
        }
    }

    ~ChallengeEndGUI() {
    }

    bool DrawButton(const string &in path, const vec2 &in pos, float ui_scale, int widget_id) {
        HUDImage @image = hud.AddImage();
        image.SetImageFromPath(path);
        float scale = ui_scale * 0.5f;
        image.position.x = pos.x;
        image.position.y = pos.y;
        image.position.z = 4;
        image.color.a = visible;
        image.scale = vec3(scale);
        UIState state;
        bool button_pressed = imui_context.DoButton(widget_id, 
            vec2(image.position.x,
            image.position.y),
            vec2(image.position.x+image.GetWidth() * image.scale.x,
            image.position.y+image.GetHeight() * image.scale.y),
            state);
        if(state == kActive){
            vec3 old_scale = image.scale;
            image.scale.x *= 0.9;
            image.scale.y *= 0.9;
            image.position.x += image.GetWidth() * (old_scale.x - image.scale.x) * 0.5f;
            image.position.y += image.GetHeight() * (old_scale.y - image.scale.y) * 0.5f;
        } else if(state == kHot){
            vec3 old_scale = image.scale;
            image.scale.x *= 1.1f;
            image.scale.y *= 1.1f;
            image.position.x += image.GetWidth() * (old_scale.x - image.scale.x) * 0.5f;
            image.position.y += image.GetHeight() * (old_scale.y - image.scale.y) * 0.5f;
        }
        return button_pressed;
    }

    void DrawGUI(){
        imui_context.UpdateControls();
        if(visible < 0.01){
            return;
        }
        float ui_scale = 0.5f;

        if(DrawButton("Data/Textures/ui/challenge_mode/quit_icon_c.tga",
            vec2(GetScreenWidth() - 256 * ui_scale * 1, 0), 
            ui_scale, 0))
        {
            level.SendMessage("go_to_main_menu");
        }
        if(DrawButton("Data/Textures/ui/challenge_mode/retry_icon_c.tga",
            vec2(GetScreenWidth() - 256 * ui_scale * 2, 0), 
            ui_scale, 1))
        {
            level.SendMessage("reset"); 
        }
        if(DrawButton("Data/Textures/ui/challenge_mode/continue_icon_c.tga",
            //if(DrawButton("Data/Textures/ui/challenge_mode/fast_forward_icon.tga",
                vec2(GetScreenWidth() - 256 * ui_scale * 3, 0), 
                ui_scale, 2))
        {
            target_visible = 0.0f;
        }
        ribbon_background.DrawGUI(visible);
    }
}

ChallengeEndGUI challenge_end_gui;


void Update() {
    bool display_achievements = false;
    if(display_achievements && GetPlayerCharacterID() != -1){
        achievements.UpdateDebugText();
    }
    challenge_end_gui.Update();
    time += time_step;
    VictoryCheckNormal();
}

int NumUnvisitedMustVisitTriggers() {
    int num_hotspots = GetNumHotspots();
    int return_val = 0;
    for(int i=0; i<num_hotspots; ++i){
        Hotspot@ hotspot = ReadHotspot(i);
        if(hotspot.GetTypeString() == "must_visit_trigger"){
            if(!hotspot.GetBoolVar("visited")){
                ++return_val;
            }
        }
    }
    return return_val;
}

int NumUnsatisfiedCollectableTargets() {
    int num_hotspots = GetNumHotspots();
    int return_val = 0;
    for(int i=0; i<num_hotspots; ++i){
        Hotspot@ hotspot = ReadHotspot(i);
        if(hotspot.GetTypeString() == "collectable_target"){
            if(!hotspot.GetBoolVar("condition_satisfied")){
                ++return_val;
            }
        }
    }
    return return_val;
}

void VictoryCheckNormal() {
    int player_id = GetPlayerCharacterID();
    if(player_id == -1){
        return;
    }
    bool victory = true;
    bool display_victory_conditions = false;

    float max_reset_delay = _reset_delay;
    for(int i=0; i<level.GetNumObjectives(); ++i){
        string objective = level.GetObjective(i);
        if(objective == "destroy_all"){
            int threats_remaining = ThreatsRemaining();
            int threats_possible = ThreatsPossible();
            if(threats_remaining > 0 || threats_possible == 0){
                victory = false;
                if(display_victory_conditions){
                    DebugText("victory_a","Did not yet defeat all enemies",0.5f);
                }
            }
        }
        if(objective == "reach_a_trigger"){
            max_reset_delay = 1.0;
            if(in_victory_trigger <= 0){
                victory = false;
                if(display_victory_conditions){
                    DebugText("victory_b","Did not yet reach trigger",0.5f);
                }
            }
        }
        if(objective == "reach_a_trigger_with_no_pursuers"){
            max_reset_delay = 1.0;
            if(in_victory_trigger <= 0){
                victory = false;
                if(display_victory_conditions){
                    DebugText("victory_c","Did not yet reach trigger",0.5f);
                }
            } else if(NumActivelyHostileThreats() > 0){
                victory = false;
                if(display_victory_conditions){
                    DebugText("victory_c","Reached trigger, but still pursued",0.5f);
                }
            } 
        }
        if(objective == "must_visit_trigger"){
            max_reset_delay = 1.0;
            if(NumUnvisitedMustVisitTriggers() != 0){
                victory = false;
                if(display_victory_conditions){
                    DebugText("victory_d","Did not visit all must-visit triggers",0.5f);
                }
            } 
        }
        if(objective == "collect"){
            max_reset_delay = 1.0;
            if(NumUnsatisfiedCollectableTargets() != 0){
                victory = false;
                if(display_victory_conditions){
                    DebugText("victory_d","Did not visit all must-visit triggers",0.5f);
                }
            } 
        }
    }
    reset_timer = min(max_reset_delay, reset_timer);

    bool failure = false;
    MovementObject@ player_char = ReadCharacter(player_id);
    if(player_char.GetIntVar("knocked_out") != _awake){
        failure = true;
    }
    if(reset_timer > 0.0f && (victory || failure)){
        reset_timer -= time_step;
        if(reset_timer <= 0.0f){
            if(reset_allowed){
                challenge_end_gui.target_visible = 1.0;
                reset_allowed = false;
            }
            if(victory){
                achievements.Save();
            }
        }
    } else {
        reset_timer = _reset_delay;
        no_win_time = time;
    }
}

void UpdateMusic() {
    int player_id = GetPlayerCharacterID();
    if(player_id != -1 && ReadCharacter(player_id).GetIntVar("knocked_out") != _awake){
        PlaySong("sad");
        return;
    }
    int threats_remaining = ThreatsRemaining();
    if(threats_remaining == 0){
        PlaySong("ambient-happy");
        return;
    }
    if(player_id != -1 && ReadCharacter(player_id).QueryIntFunction("int CombatSong()") == 1){
        PlaySong("combat");
        return;
    }
    PlaySong("ambient-tense");
}
