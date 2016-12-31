#include "ui_effects.as"
#include "dialogue.as"
#include "ogmp_level.as"

int controller_id = 0;
bool has_gui = false;
uint32 gui_id;
bool has_display_text = false;
uint32 display_text_id;
string hotspot_image_string;
bool menu_paused = false;
bool allow_retry = true;

Dialogue dialogue;

class DialogueTextCanvas {
    string text;
    int obj_id;
    int canvas_id;
};

array<DialogueTextCanvas> dialogue_text_canvases;
array<int> number_text_canvases;

void SaveHistoryState(SavedChunk@ chunk) {
    dialogue.SaveHistoryState(chunk);
}

void ReadChunk(SavedChunk@ chunk) {
    dialogue.ReadChunk(chunk);
}

void DrawDialogueTextCanvas(int obj_id){
    Object @obj = ReadObjectFromID(obj_id);
    ScriptParams@ params = obj.GetScriptParams();
    if(!params.HasParam("DisplayName")){
        return;
    }
    string new_string = params.GetString("DisplayName");

    int num_canvases = int(dialogue_text_canvases.size());
    int assigned_canvas = -1;
    for(int i=0; i<num_canvases; ++i){
        if(dialogue_text_canvases[i].obj_id == obj_id){
            assigned_canvas = i;
        }
    }
    if(assigned_canvas == -1){
        dialogue_text_canvases.resize(num_canvases+1);
        dialogue_text_canvases[num_canvases].obj_id = obj_id;
        dialogue_text_canvases[num_canvases].text = "";
        dialogue_text_canvases[num_canvases].canvas_id = level.CreateTextElement();
        TextCanvasTexture @text = level.GetTextElement(dialogue_text_canvases[num_canvases].canvas_id);
        text.Create(256, 256);
        assigned_canvas = num_canvases;
    }
    DialogueTextCanvas @assigned = dialogue_text_canvases[assigned_canvas];
    TextCanvasTexture @text = level.GetTextElement(assigned.canvas_id);
    if(assigned.text != new_string){
        text.ClearTextCanvas();
        string font_str = "Data/Fonts/arial.ttf";
        TextStyle small_style;
        int font_size = 24;
        small_style.font_face_id = GetFontFaceID(font_str, font_size);
        text.SetPenColor(255,255,255,255);
        text.SetPenRotation(0.0f);
        TextMetrics metrics;
        text.GetTextMetrics(new_string, small_style, metrics, UINT32MAX);
        text.SetPenPosition(vec2(128-metrics.advance_x/64.0f*0.5f, 210));
        text.AddText(new_string, small_style,UINT32MAX);
        text.UploadTextCanvasToTexture();
        assigned.text = new_string;
    }
    text.DebugDrawBillboard(obj.GetTranslation(), obj.GetScale().x, _delete_on_update);
}

void Init(string p_level_name) {
    dialogue.Init();
    level_name = p_level_name;
    int num_number_canvases = 9;
    number_text_canvases.resize(num_number_canvases);
    for(int i=0; i<num_number_canvases; ++i){
        number_text_canvases[i] = level.CreateTextElement();
        TextCanvasTexture @text = level.GetTextElement(number_text_canvases[i]);
        text.Create(32, 32);
        text.ClearTextCanvas();
        string font_str = "Data/Fonts/arial.ttf";
        TextStyle small_style;
        int font_size = 24;
        small_style.font_face_id = GetFontFaceID(font_str, font_size);
        text.SetPenColor(255,255,255,255);
        text.SetPenRotation(0.0f);
        TextMetrics metrics;
        string new_string = ""+(i+1);
        text.GetTextMetrics(new_string, small_style, metrics, UINT32MAX);
        text.SetPenPosition(vec2(16-metrics.advance_x/64.0f*0.5f, 24));
        text.AddText(new_string, small_style,UINT32MAX);
        text.UploadTextCanvasToTexture();
    }
}

int HasCameraControl() {
    return dialogue.HasCameraControl()?1:0;
}

void GUIDeleted(uint32 id){
    if(id == gui_id){
        has_gui = false;
    }
    if(id == display_text_id){
        has_display_text = false;
    }
}

bool HasFocus(){
    return HasOGMPFocus();
}

void CharactersNoticeEachOther() {
    int num_chars = GetNumCharacters();
    for(int i=0; i<num_chars; ++i){
         MovementObject@ char = ReadCharacter(i);
         char.ReceiveMessage("set_omniscient true");
         for(int j=i+1; j<num_chars; ++j){
             MovementObject@ char2 = ReadCharacter(j);
             //Print("Telling characters " + char.GetID() + " and " + char2.GetID() + " to notice each other.\n");
             char.ReceiveMessage("notice " + char2.GetID());
             char2.ReceiveMessage("notice " + char.GetID());
         }
     }
}

void ReceiveMessage(string msg) {
    TokenIterator token_iter;
    token_iter.Init();
    if(!token_iter.FindNextToken(msg)){
        return;
    }
    string token = token_iter.GetToken(msg);
    if(token == "cleartext"){
        if(has_display_text){
            gui.RemoveGUI(display_text_id);
            has_display_text = false;
        }
    } else if(token == "dispose_level"){
        gui.RemoveAll();
        has_gui = false;
    } else if(token == "disable_retry"){
        allow_retry = false;
    } else if(token == "go_to_main_menu"){
        level.SendMessage("dispose_level");
        LoadLevel("back");
    } else if(token == "clearhud"){
	    hotspot_image_string.resize(0);
	} else if(token == "manual_reset"){
        level.SendMessage("reset");
    } else if(token == "reset"){
        dialogue.Init();
        ResetLevel();
    } else if(token == "displaytext"){
        if(has_display_text){
            gui.RemoveGUI(display_text_id);
        }
        display_text_id = gui.AddGUI("text2","script_text.html",400,200, _GG_IGNORES_MOUSE);
        token_iter.FindNextToken(msg);
        gui.Execute(display_text_id,"SetText(\""+token_iter.GetToken(msg)+"\")");
        has_display_text = true;
    }else if(token == "displayvideo"){
		token_iter.FindNextToken(msg);
		DebugText("awe", "" + msg, _fade);
        gui_id = gui.AddGUI("video",token_iter.GetToken(msg),GetScreenWidth() - 200,GetScreenHeight() - 200,0);
    } else if(token == "removevideo"){
		gui.RemoveGUI(gui_id);
    }else if(token == "displaygui"){
        token_iter.FindNextToken(msg);
        gui_id = gui.AddGUI("displaygui_call",token_iter.GetToken(msg),220,250,0);
        has_gui = true;
    } else if(token == "displayhud"){
		if(hotspot_image_string.length() == 0){
		    token_iter.FindNextToken(msg);
            hotspot_image_string = token_iter.GetToken(msg);
		}
    } else if(token == "loadlevel"){
        level.SendMessage("dispose_level");
		token_iter.FindNextToken(msg);
        LoadLevel(token_iter.GetToken(msg));
    } else if(token == "make_all_aware"){
        CharactersNoticeEachOther();
    } else if(token == "start_dialogue"){
		token_iter.FindNextToken(msg);
        dialogue.StartDialogue(token_iter.GetToken(msg));
    } else if(token == "open_menu") {
        if(!level.HasFocus()){
            if(EditorEnabled()){
                gui_id = gui.AddGUI("gamemenu","dialogs\\editorgamemenu.html",220,290,0);
            } else {
                if(allow_retry){
                    gui_id = gui.AddGUI("gamemenu","dialogs\\gamemenu.html",220,260,0);
                } else {
                    gui_id = gui.AddGUI("gamemenu","dialogs\\arenagamemenu.html",220,230,0);
                }
            }
            SetPaused(true);
            menu_paused = true;
            has_gui = true;
        }
    } else {
        dialogue.ReceiveMessage(msg);
    }
}

void DrawGUI() {
    if(hotspot_image_string.length() != 0){
        HUDImage@ image = hud.AddImage();
        image.SetImageFromPath(hotspot_image_string);
        image.position = vec3(700,200,0);
    }
    dialogue.Display();
}

void Update(int paused) {
    if(level.HasFocus()){
        SetGrabMouse(false);
    } else {
        if(menu_paused){
            SetPaused(false);
            menu_paused = false;
        }
    }

    /*SetSunColor(vec3(sin(the_time*1.35)*0.5f+0.5f, sin(the_time*1.15)*0.5f+0.5f, sin(the_time*1.75)*0.5f+0.5f)*3.0f);
    SetSunPosition(vec3(sin(the_time), 1.0, cos(the_time)));
    SetSunAmbient((sin(the_time*1.25)*0.5f+0.5f) * 3.0);
    SetFlareDiffuse((1.0f - (sin(the_time*1.25)*0.5f+0.5f)) * 5.0);
    SetSkyTint(vec3(sin(the_time*1.3)*0.5f+0.5f, sin(the_time*1.1)*0.5f+0.5f, sin(the_time*1.7)*0.5f+0.5f)*3.0f);
    */
    /*
    SetSunColor(vec3(0.0f));
    SetSkyTint(vec3(0.0f));
    SetSunAmbient(3.0);*/
    if(has_gui){
        EnterTelemetryZone("Update gui");
        string callback = gui.GetCallback(gui_id);
        while(callback != ""){
            Print("AS Callback: "+callback+"\n");
            if(callback == "retry"){
                gui.RemoveGUI(gui_id);
                has_gui = false;
                level.SendMessage("reset");
                break;
            }
            if(callback == "continue"){
                gui.RemoveGUI(gui_id);
                has_gui = false;
                break;
            }
            if(callback == "mainmenu"){
                if(CheckSaveLevelChanges()){
                    level.SendMessage("go_to_main_menu");
                }
                break;
            }
            if(callback == "media_mode"){
                SetMediaMode(true);
                gui.RemoveGUI(gui_id);
                has_gui = false;
            }
            if(callback == "settings"){
                gui.RemoveGUI(gui_id);
                OpenSettings(context);
                has_gui = false;
                break;
            }
            callback = gui.GetCallback(gui_id);
        }
        LeaveTelemetryZone();
    }

    UpdateOGMP();

    if(!has_gui && GetInputDown(controller_id, "esc") && GetPlayerCharacterID() == -1){
        gui_id = gui.AddGUI("gamemenu","dialogs\\gamemenu.html",220,290,0);
        has_gui = true;
    }

    if(!connected_to_server){
        if(DebugKeysEnabled() && GetInputPressed(controller_id, "l")){
            level.SendMessage("manual_reset");
        }

        if(DebugKeysEnabled() && GetInputDown(controller_id, "x")){
            int num_items = GetNumItems();
            for(int i=0; i<num_items; i++){
                ItemObject@ item_obj = ReadItem(i);
                item_obj.CleanBlood();
            }
        }
    }
    EnterTelemetryZone("Update dialogue");
    dialogue.Update();
    LeaveTelemetryZone();
    EnterTelemetryZone("SetAnimUpdateFreqs");
    SetAnimUpdateFreqs();
    LeaveTelemetryZone();
}

const float _max_anim_frames_per_second = 100.0f;

void SetAnimUpdateFreqs() {
    int num = GetNumCharacters();
    array<float> framerate_request(num);
    vec3 cam_pos = camera.GetPos();
    float total_framerate_request = 0.0f;
    for(int i=0; i<num; ++i){
        MovementObject@ char = ReadCharacter(i);
        if(char.controlled || char.QueryIntFunction("int NeedsAnimFrames()") == 0){
            continue;
        }
        float dist = distance(char.position, cam_pos);
        framerate_request[i] = 120.0f/max(2.0f,min(dist*0.5f,32.0f));
        framerate_request[i] = max(15.0f,framerate_request[i]);
        total_framerate_request += framerate_request[i];
    }
    float scale = 1.0f;
    if(total_framerate_request != 0.0f){
        scale *= _max_anim_frames_per_second/total_framerate_request;
    }
    for(int i=0; i<num; ++i)
{        MovementObject@ char = ReadCharacter(i);
        int needs_anim_frames = char.QueryIntFunction("int NeedsAnimFrames()");
        if(char.controlled || needs_anim_frames==0){
            continue;
        }
        int period = int(120.0f/(framerate_request[i]*scale));
        period = int(min(10,max(4, period)));
        if(needs_anim_frames == 2){
            period = min(period, 4);
        }
        if(char.GetIntVar("tether_id") != -1){
            char.rigged_object().SetAnimUpdatePeriod(2);
            char.SetScriptUpdatePeriod(2);
        } else {
            char.rigged_object().SetAnimUpdatePeriod(period);
            char.SetScriptUpdatePeriod(4);
        }
    }
}

int GetPlayerCharacterID() {
    int num = GetNumCharacters();
    for(int i=0; i<num; ++i){
        MovementObject@ char = ReadCharacter(i);
        if(char.controlled){
            return i;
        }
    }
    return -1;
}

void HotspotEnter(string str, MovementObject @mo) {
    if(str == "Stop"){
        level.SendMessage("reset");
    }
}

void HotspotExit(string str, MovementObject @mo) {
}



JSON getArenaSpawns() {
    JSON testValue;

    Print("Starting getArenaSpawns\n");

    JSONValue jsonArray( JSONarrayValue );

    // Go through and record all possible spawn locations, store them by name
    dictionary spawnLocations; // All the spawn locations map from name to object id
    array<int> @allObjectIds = GetObjectIDs();
    for( uint objectIndex = 0; objectIndex < allObjectIds.length(); objectIndex++ ) {
        Object @obj = ReadObjectFromID( allObjectIds[ objectIndex ] );
        ScriptParams@ params = obj.GetScriptParams();
        if(params.HasParam("Name") && params.GetString("Name") == "arena_spawn" ) {
            if(params.HasParam("LocName") ) {
                string LocName = params.GetString("LocName");
                if( LocName != "" ) {
                    if( spawnLocations.exists( LocName ) ) {
                        DisplayError("Error", "Duplicate spawn location " + LocName );
                    }
                    else {
                        spawnLocations[ LocName ] = allObjectIds[ objectIndex ];
                        jsonArray.append( JSONValue( LocName ) );
                    }
                }
            }
        }
    }

    testValue.getRoot() = jsonArray;

    Print("Done getArenaSpawns\n");

    return testValue;

}

void TextInput( string text )
{
    dialogue.TextInput(text);
}

void KeyPressed( string command, bool repeated )
{
    dialogue.KeyPressed(command,repeated);
}

void KeyReleased( string command )
{
    dialogue.KeyReleased(command);
}

uint PollKeyboardFocus()
{
    return dialogue.PollKeyboardFocus();
}

void SetWindowDimensions(int w, int h)
{
    dialogue.ResizeUpdate(w,h);
}
