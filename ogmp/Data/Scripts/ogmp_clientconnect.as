uint socket = SOCKET_ID_INVALID;
uint connect_try_countdown = 5;
string level_name = "";
int player_id = -1;
IMGUI imGUI;

string username = "";
string team = "";
string welcome_message = "";
string character = "";
FontSetup main_font("edosz", 100 , HexColor("#CCCCCC"), true);

string turner = "Data/Characters/ogmp/turner.xml";

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
float blood_damage = 0.0f;
float blood_health = 1.0f;
float block_health = 1.0f;
float temp_health = 1.0f;
float permanent_health = 1.0f;
int knocked_out = 0;
int lives = 1;
float blood_amount = 10.0f;
float recovery_time = 1.0f;
float roll_recovery_time = 1.0f;
int ragdoll_type = 0;
int blood_delay = 0;
bool cut_throat = false;
int state = 0;


bool connected_to_server = false;
bool post_init_run = false;
bool trying_to_connect = false;
bool showing_playerlist = false;

float update_timer = 0.0f;
float interval = 1.0f;
int refresh_rate = 30;

//Message types 
uint8 SignOn = 0;
uint8 Message = 1;
uint8 TimeOut = 2;
uint8 SpawnCharacter = 3;
uint8 RemoveCharacter = 4;
uint8 UpdateGame = 5;
uint8 UpdateSelf = 6;
uint8 SavePosition = 7;
uint8 LoadPosition = 8;
uint8 UpdateCharacter = 9;
uint8 Error = 10;

int username_size = 10;
int character_size = 10;
int level_size = 10;
int version_size = 10;
int float_size = 10;

bool TCPReceived = false;

array<RemotePlayer@> remote_players;

IMDivider@ main_divider;

class RemotePlayer{
	int object_id;
	string username;
	string team;
	RemotePlayer(string username_, string team_, int object_id_){
		username = username_;
		team = team_;
		object_id = object_id_;
	}
}

void Init(string p_level_name) {
    level_name = p_level_name;
	imGUI.setFooterHeight(600);
	imGUI.setup();
	@main_divider = IMDivider("main_divider", DOVertical);
	imGUI.getFooter().setElement(main_divider);
    player_id = GetPlayerCharacterID();
}

void IncomingTCPData(uint socket, array<uint8>@ data) {
	/*Log(info, "Data in size " + data.length() );*/
    for( uint i = 0; i < data.length(); i++ ) {
		/*Print(data[i] + " ");*/
        Print(data[i] + " ");
    }
	Print("\n");
	PrintByteArray(data);
	ProcessIncomingMessage(data);
}

void ProcessIncomingMessage(array<uint8>@ data){
	uint8 message_type = data[0];
	Log(info, "Message type : " + message_type);
	int data_index = 1;
	if(message_type == SignOn){
		Log(info, "Incoming: " + "SignOn Command");
		float refresh_rate = GetFloat(data, data_index);
		string username = GetString(data, data_index);
		Log(info, "username: " + username);
		string welcome_message = GetString(data, data_index);
		Log(info, "welcome_message: " + welcome_message);
		string team = GetString(data, data_index);
		Log(info, "team: " + team);
		string character = GetString(data, data_index);
		Log(info, "character: " + character);
		connected_to_server = true;
		interval = 1.0 / refresh_rate;
		Log(info, "interval: " + interval);
	}
	else if(message_type == Message){
		Log(info, "Incoming: " + "Message Command");
		string message_source = GetString(data, data_index);		
		string message_text = GetString(data, data_index);		
		bool notif = GetBool(data, data_index);		
		IMText label_source("From " + message_source, main_font);
		IMText label_text("Message: " + message_text, main_font);
		
		IMText label_notif("Is notification " + notif, main_font);
		main_divider.append(label_source);
		main_divider.append(label_text);
		main_divider.append(label_notif);
	}
	else if (message_type == SpawnCharacter){
		Log(info, "Incoming: " + "SpawnCharacter Command");
		string username = GetString(data, data_index);
		string team = GetString(data, data_index);
		string character = GetString(data, data_index);
		float pos_x = GetFloat(data, data_index);
		float pos_y = GetFloat(data, data_index);
		float pos_z = GetFloat(data, data_index);
		CreateRemotePlayer(username, team, character, vec3(pos_x, pos_y, pos_z));
	}
	else if (message_type == RemoveCharacter){
		Log(info, "Incoming: " + "RemoveCharacter Command");
	}
	else if (message_type == UpdateGame){
		Log(info, "Incoming: " + "Update Command");
	}
	else if (message_type == UpdateSelf){
		Log(info, "Incoming: " + "UpdateSelf Command");
	}
	else if (message_type == UpdateCharacter){
		Log(info, "Incoming: " + "UpdateCharacter Command");
		
		string remote_username = GetString(data, data_index);
		float remote_posx = GetFloat(data, data_index);
		float remote_posy = GetFloat(data, data_index);
		float remote_posz = GetFloat(data, data_index);
		float remote_dirx = GetFloat(data, data_index);
		float remote_dirz = GetFloat(data, data_index);
		
		bool remote_crouch = GetBool(data, data_index);
		bool remote_jump = GetBool(data, data_index);
		bool remote_attack = GetBool(data, data_index);
		bool remote_grab = GetBool(data, data_index);
		bool remote_item = GetBool(data, data_index);
		bool remote_drop = GetBool(data, data_index);
		bool remote_roll = GetBool(data, data_index);
		bool remote_jumpoffwall = GetBool(data, data_index);
		bool remote_activateblock = GetBool(data, data_index);
		
		float remote_blooddamage = GetFloat(data, data_index);
		float remote_bloodhealth = GetFloat(data, data_index);
		float remote_blockhealth = GetFloat(data, data_index);
		float remote_temphealth = GetFloat(data, data_index);
		float remote_permanenthealth = GetFloat(data, data_index);
		
		int remote_knockedout = GetInt(data, data_index);
		int remote_lives = GetInt(data, data_index);
		
		float remote_bloodamount = GetFloat(data, data_index);
		float remote_recoverytime = GetFloat(data, data_index);
		float remote_rollrecoverytime = GetFloat(data, data_index);
		
		bool remote_removeblood = GetBool(data, data_index);
		int remote_blooddelay = GetInt(data, data_index);
		bool remote_cutthroat = GetBool(data, data_index);
		int remote_state = GetInt(data, data_index);
		
		MovementObject@ remote_player = GetRemotePlayer(remote_username);
		if(remote_player !is null){
			remote_player.position = vec3(remote_posx, remote_posy, remote_posz);
			remote_player.Execute("dir_x = " + remote_dirx + ";");
			remote_player.Execute("dir_z = " + remote_dirz + ";");
			/*Print("player_dir " + player_dir.x + " " + player_dir.z + "\n");*/
		}else{
			Print("Can't find the user " + remote_username);
		}
	}
	else if (message_type == Error){
		Log(info, "Incoming: " + "Error Command");
		Print("Error message " + GetString(data, data_index) + "\n");
	}
	else{
		//DisplayError("Unknown Message", "Unknown incomming message: " + message_type);
	}
}

MovementObject@ GetRemotePlayer(string username){
	for(uint i = 0; i < remote_players.size(); i++){
		if(remote_players[i].username == username){
			MovementObject@ found_remote_player = ReadCharacterID(remote_players[i].object_id);
			return found_remote_player;
		}
	}
	return null;
}

void CreateRemotePlayer(string username, string team, string character, vec3 position){
	int obj_id = CreateObject(turner);
	remote_players.insertLast(RemotePlayer(username, team, obj_id));
	MovementObject@ remote_player = ReadCharacterID(obj_id);
	Object@ object = ReadObjectFromID(obj_id);
	ScriptParams@ params = object.GetScriptParams();
	params.SetString("Teams", team);
	remote_player.position = position;
}

void PrintByteArray(array<uint8> data){
	array<string> complete;
    for( uint i = 0; i < data.length(); i++ ) {
        string s('0');
        s[0] = data[i];
        complete.insertLast(s);
		Print(s);
    }
	Print("\n");
    /*Log(info, "Incoming: " + join(complete, ""));*/
}

void ReceiveMessage(string msg) {
}

void DrawGUI() {
	imGUI.render();
}

void Update() {
	Update(0);
}

void Update(int paused) {
    if(!post_init_run){
        player_id = GetPlayerCharacterID();
        post_init_run = true;
    }

    if(connected_to_server){
		if(update_timer > interval){
			UpdatePlayerVariables();
	        SendPlayerUpdate();
			update_timer = 0;
	    }
	    update_timer += time_step;
        ReceiveServerUpdate();
		KeyChecks();
    }else{
        PreConnectedKeyChecks();
        ConnectToServer();
    }
	// process any messages produced from the update
    while( imGUI.getMessageQueueSize() > 0 ) {
        IMMessage@ message = imGUI.getNextMessage();
		if( message.name == "" ){return;}
        //Log( info, "Got processMessage " + message.name );
	}
	imGUI.update();
}

void SetWindowDimensions(int w, int h)
{
	imGUI.doScreenResize();
}

void PreConnectedKeyChecks(){
    if(GetInputPressed(ReadCharacter(player_id).controller_id, "f12") && !trying_to_connect){
        Log(info, "Trying to connect to server");
        trying_to_connect = true;
    }
	else if(GetInputPressed(ReadCharacter(player_id).controller_id, "f5")){
		
	}
}

void KeyChecks(){
	int controller_id = ReadCharacter(player_id).controller_id;

	if(GetInputPressed(controller_id, "return")) {
		//TODO closing and opening chat.
	}
	else if(GetInputDown(controller_id, "f10")) {
		if(!showing_playerlist) {
			//TODO show player list while f10 is being pressed
			showing_playerlist = true;
		}
	}
	else if(showing_playerlist && !GetInputDown(controller_id, "f10")) {
		//TODO don't show playerlist anymore.
		showing_playerlist = false;
	}
	else if(GetInputPressed(controller_id, "f12")) {
		DisconnectFromServer();
	}
	else if(GetInputPressed(controller_id, "k")) {
		if((permanent_health > 0) && (temp_health > 0)) {
			SendSavePosition();
		}
	}
	else if(GetInputPressed(controller_id, "l")) {
		if((permanent_health > 0) && (temp_health > 0)) {
			SendLoadPosition();
		}
	}
}

void ConnectToServer(){
    if(trying_to_connect){
        if( socket == SOCKET_ID_INVALID ) {
            if( level_name != "") {
                Log( info, "Trying to connect" );
				socket = CreateSocketTCP("127.0.0.1", 2000);
                if( socket != SOCKET_ID_INVALID ) {
                    Log( info, "Connected " + socket );
					trying_to_connect = false;
					SendSignOn();
                } else {
                    Log( warning, "Unable to connect, will try again soon" );
                }
            }
        }
		if( !IsValidSocketTCP(socket) ){
			Log(info, "Socket no longer valid");
			socket = SOCKET_ID_INVALID;
			connected_to_server = false;
			trying_to_connect = false;
		}
    }
}

void DisconnectFromServer(){
	Print("Destroying socket\n");
	DestroySocketTCP(socket);
	socket = SOCKET_ID_INVALID;
	connected_to_server = false;
}

void SendChatMessage(string chat_message){
	JSON message;
	message.getRoot()["type"] = JSONValue("Message");
	JSONValue message_type;
	message_type["username"] = JSONValue("Gyrth");
	message_type["text"] = JSONValue(chat_message);
	message.getRoot()["content"] = message_type;
	/*SendData(message.writeString(false));*/
}

void SendSavePosition(){
	JSON message;
	message.getRoot()["type"] = JSONValue("SavePosition");
	/*SendData(message.writeString(false));*/
}

void SendLoadPosition(){
	JSON message;
	message.getRoot()["type"] = JSONValue("LoadPosition");
	/*SendData(message.writeString(false));*/
}

void SendSignOn(){
	array<uint8> message;
	message.insertLast(SignOn);
	MovementObject@ player = ReadCharacter(player_id);
	vec3 position = player.position;
	
	addToByteArray("Gyrth" + rand(), @message);
	addToByteArray("Turner", @message);
	addToByteArray(level_name, @message);
	addToByteArray("1.0.0", @message);
	addToByteArray(position.x, @message);
	addToByteArray(position.y, @message);
	addToByteArray(position.z, @message);
	
	
	/*Print("Sending: \n");
	for(uint i = 0; i < message.size(); i++){
		Print("" + message[i]);
	}
	Print("\n");
	Print("Send done.\n");*/
	//message.insertLast('\n'[0]);
	SendData(message);
	//Print(message.writeString(false) + "\n");
}

array<uint8> toByteArray(string message){
	array<uint8> data;
	for(uint i = 0; i < message.length(); i++){
		data.insertLast(message.substr(i, 1)[0]);
	}
	/*data.insertLast('\n'[0]);*/
	return data;
}

void addToByteArray(string message, array<uint8> @data){
	Print("Adding a string to message " + message + "\n");
	uint8 message_length = message.length();
	Print("Length " + message_length + "\n");
	data.insertLast(message_length);
	for(uint i = 0; i < message_length; i++){
		data.insertLast(message.substr(i, 1)[0]);
	}
}

void addToByteArray(float value, array<uint8> @data){
	/*Print("sending " + value + "\n");*/
	array<uint8> bytes = toByteArray(value);
	for(uint i = 0; i < 4; i++){
		data.insertLast(bytes[i]);
	}
}

void addToByteArray(bool value, array<uint8> @data){
	if(value){
		data.insertLast(1);
	}else{
		data.insertLast(0);
	}
}

float GetFloat(array<uint8>@ data, int &start_index){
	array<uint8> b = {data[start_index + 3], data[start_index + 2], data[start_index + 1], data[start_index]};
	/*array<uint8> b = {data[start_index], data[start_index + 1], data[start_index + 2], data[start_index + 3]};*/
	float f = toFloat(b);
	start_index += 4;
	return f;
}

string GetString(array<uint8>@ data, int &start_index){
	array<string> seperated;
	int string_size = data[start_index];
	start_index++;
    for( int i = 0; i < string_size; i++, start_index++ ) {
		//Skip if the char is not an actual number/letter/etc
		if(data[start_index] < 32){
			continue;
		}
        string s('0');
        s[0] = data[start_index];
        seperated.insertLast(s);
    }
    return join(seperated, "");
}

bool GetBool(array<uint8>@ data, int &start_index){
	
	uint8 b = data[start_index];
	start_index++;
	if(b == 1){
		return true;
	}else{
		return false;
	}
}

int GetInt(array<uint8>@ data, int &start_index){
	uint8 b = data[start_index];
	start_index++;
	return int(b);
}

array<uint8> toByteArray(float f){
	uint p = fpToIEEE(f);
	array<uint8> bytes(4);
	bytes[0] = p >> 24;
	bytes[1] = p >> 16;
	bytes[2] = p >>  8;
	bytes[3] = p;
	return bytes;
}

float toFloat(array<uint8> bytes){
	uint s = bytes[3] & 0xFF;
        s |= (bytes[2] << 8) & 0xFFFF;
        s |= (bytes[1] << 16) & 0xFFFFFF;
        s |= (bytes[0] << 24);
	
	return fpFromIEEE(s);
}

/*char* request_handler::floatToByteArray(float f) {
	char *array;
	array = (char*)(&f);
	return array;
}*/

void SendPlayerUpdate(){
	
	array<uint8> message;
	message.insertLast(UpdateGame);
	MovementObject@ player = ReadCharacter(player_id);
	vec3 position = player.position;
	
	addToByteArray(player.position.x, @message);
	addToByteArray(player.position.y, @message);
	addToByteArray(player.position.z, @message);
	vec3 player_dir = GetPlayerTargetVelocity();
	/*Print("player_dir " + player_dir.x + " " + player_dir.z + "\n");*/
	addToByteArray(player_dir.x, @message);
	addToByteArray(player_dir.z, @message);
	
	addToByteArray(MPWantsToCrouch, @message);
	addToByteArray(MPWantsToJump, @message);
	addToByteArray(MPWantsToAttack, @message);
	addToByteArray(MPWantsToGrab, @message);
	addToByteArray(MPWantsToItem, @message);
	addToByteArray(MPWantsToDrop, @message);
	addToByteArray(MPWantsToRoll, @message);
	addToByteArray(MPWantsToJumpOffWall, @message);
	addToByteArray(MPActiveBlock, @message);
	
	addToByteArray(blood_damage, @message);
	addToByteArray(blood_health, @message);
	addToByteArray(block_health, @message);
	addToByteArray(temp_health, @message);
	addToByteArray(permanent_health, @message);
	addToByteArray(knocked_out, @message);
	addToByteArray(lives, @message);
	addToByteArray(blood_amount, @message);
	
	addToByteArray(recovery_time, @message);
	addToByteArray(roll_recovery_time, @message);
	addToByteArray(ragdoll_type, @message);
	addToByteArray(blood_delay, @message);
	addToByteArray(cut_throat, @message);
	addToByteArray(state, @message);

	MPWantsToRoll = false;
	MPWantsToJumpOffWall = false;
	MPActiveBlock = false;

	SendData(message);
	//Print(message.writeString(false) + "\n");
	//array<string> messages = {"This is the first message", "and another one", "bloop", "soooo", "hmm yeah"};
	//SendData(messages[rand()%messages.size()]);
}

vec3 GetPlayerTargetVelocity() {
    vec3 target_velocity(0.0f);    
    vec3 right;
    {
        right = camera.GetFlatFacing();
        float side = right.x;
        right.x = -right .z;
        right.z = side;
    }
	int controller_id = ReadCharacter(player_id).controller_id;

    target_velocity -= GetMoveYAxis(controller_id)*camera.GetFlatFacing();
    target_velocity += GetMoveXAxis(controller_id)*right;

    if(length_squared(target_velocity)>1){
        target_velocity = normalize(target_velocity);
    }
    /*if(trying_to_get_weapon > 0){
        target_velocity = get_weapon_dir;
    }*/
    return target_velocity;
}

void ReceiveServerUpdate(){
	
}

void UpdatePlayerVariables(){
	int controller_id = ReadCharacter(player_id).controller_id;
	MovementObject@ player = ReadCharacter(player_id);
    MPWantsToCrouch = GetInputDown(controller_id, "crouch");
    MPWantsToJump = GetInputDown(controller_id, "jump");
    MPWantsToAttack = GetInputDown(controller_id, "attack");
    MPWantsToGrab = GetInputDown(controller_id, "grab");
    MPWantsToItem = GetInputDown(controller_id, "item");
    MPWantsToDrop = GetInputDown(controller_id, "drop");

	blood_damage = player.GetFloatVar("blood_damage");
	blood_health = player.GetFloatVar("blood_health");
	block_health = player.GetFloatVar("block_health");
	temp_health = player.GetFloatVar("temp_health");
	permanent_health = player.GetFloatVar("permanent_health");
	blood_amount = player.GetFloatVar("blood_amount");
	recovery_time = player.GetFloatVar("recovery_time");
	roll_recovery_time = player.GetFloatVar("roll_recovery_time");
	knocked_out = player.GetIntVar("knocked_out");
	//lives = player.GetIntVar("lives");
	ragdoll_type = player.GetIntVar("ragdoll_type");
	blood_delay = player.GetIntVar("blood_delay");
	state = player.GetIntVar("state");
	cut_throat = player.GetBoolVar("cut_throat");

    if(GetInputPressed(controller_id, "crouch")) {
      MPWantsToRoll = true;
    }
    if(GetInputPressed(controller_id, "jump")) {
      MPWantsToJumpOffWall = true;
    }
    if(GetInputPressed(controller_id, "grab")) {
      MPActiveBlock = true;
    }
    //dir_x = ReadCharacter(player_id).GetFloatVar("GetTargetVelocity().x");
    //dir_z = ReadCharacter(player_id).GetFloatVar("GetTargetVelocity().y");
    //Log(info, dir_x + " dir_x");
    //Log(info, dir_z + " dir_z");
}

void SendData(array<uint8> message){
    if( IsValidSocketTCP(socket) )
    {
        /*Log(info, "Sending data" );
        Log(info, "Data size " + message.size() );*/
        SocketTCPSend(socket,message);
    }
    else
    {
		Log(info, "Socket no longer valid");
        socket = SOCKET_ID_INVALID;
		connected_to_server = false;
		trying_to_connect = false;
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
bool HasFocus(){
	return false;
}
