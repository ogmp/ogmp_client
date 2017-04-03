uint socket = SOCKET_ID_INVALID;
uint connect_try_countdown = 5;
string level_name = "";
int player_id = -1;

string username = "";
string team = "";
string welcome_message = "";
string character = "";

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

int username_size = 10;
int character_size = 10;
int level_size = 10;
int version_size = 10;
int float_size = 10;
int string_size = 20;

bool TCPReceived = false;

void Init(string p_level_name) {
    level_name = p_level_name;
    player_id = GetPlayerCharacterID();
}

void IncomingTCPData(uint socket, array<uint8>@ data) {
	Log(info, "Data in size " + data.length() );
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
		float refresh_rate = GetFloat(data, data_index);
		string username = GetString(data, data_index);
		Log(info, "username: " + username);
		string welcome_message = GetString(data, data_index);
		Log(info, "welcome_message: " + welcome_message);
		string team = GetString(data, data_index);
		Log(info, "team: " + team);
		string character = GetString(data, data_index);
		Log(info, "character: " + character);
		
		/*refresh_rate = atoi(message_content["refresh_rate"].asString());
		username = message_content["username"].asString();
		welcome_message = message_content["welcome_message"].asString();
		team = message_content["team"].asString();
		character = message_content["character"].asString();
		connected_to_server = true;*/
	}
	else if(message_type == Message){
		Log(info, "Incoming: " + "Message Command");
	}
	else if (message_type == SpawnCharacter){
		Log(info, "Incoming: " + "SpawnCharacter Command");
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
	else{
		//DisplayError("Unknown Message", "Unknown incomming message: " + message_type);
	}
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
}

void SetWindowDimensions(int w, int h)
{
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
            if( connect_try_countdown == 0 ) {
                if( level_name != "") {
                    Log( info, "Trying to connect" );
					socket = CreateSocketTCP("127.0.0.1", 2000);
                    if( socket != SOCKET_ID_INVALID ) {
                        Log( info, "Connected " + socket );
						trying_to_connect = false;
						SendSignOn();
                    } else {
                        Log( warning, "Unable to connect, will try again soon" );
                        connect_try_countdown = 60*5;
                    }
                }
            } else {
                connect_try_countdown--;
            }
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
	
	addToByteArray("Gyrth", username_size, @message);
	addToByteArray("Turner", character_size, @message);
	addToByteArray("red_shards.xml", level_size, @message);
	addToByteArray("1.0.0", version_size, @message);
	addToByteArray(position.x, float_size, @message);
	addToByteArray(position.y, float_size, @message);
	addToByteArray(position.z, float_size, @message);
	
	
	Print("Sending: \n");
	for(uint i = 0; i < message.size(); i++){
		Print("" + message[i]);
	}
	Print("\n");
	Print("Send done.\n");
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

void addToByteArray(string message, uint message_length, array<uint8> @data){
	for(uint i = 0; i < message_length; i++){
		if(i >= message.length()){
			data.insertLast(0);
		}else{
			data.insertLast(message.substr(i, 1)[0]);
		}
	}
}

void addToByteArray(float value, int message_length, array<uint8> @data){
	/*Print("sending " + value + "\n");*/
	array<uint8> bytes = toByteArray(value);
	for(uint i = 0; i < bytes.size(); i++){
		data.insertLast(bytes[i]);
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
	JSON message;
	JSONValue message_type;
	MovementObject@ char = ReadCharacter(0);

	message.getRoot()["type"] = JSONValue("Update");
	message_type["posx"] = JSONValue(char.position.x);
	message_type["posy"] = JSONValue(char.position.y);
	message_type["posz"] = JSONValue(char.position.z);
	//TODO corrent x and z
	message_type["dirx"] = JSONValue(char.position.x);
	message_type["dirz"] = JSONValue(char.position.z);
	message_type["crouch"] = JSONValue(MPWantsToCrouch);
	message_type["jump"] = JSONValue(MPWantsToJump);
	message_type["attack"] = JSONValue(MPWantsToAttack);
	message_type["grab"] = JSONValue(MPWantsToGrab);
	message_type["item"] = JSONValue(MPWantsToItem);
	message_type["drop"] = JSONValue(MPWantsToDrop);
	message_type["roll"] = JSONValue(MPWantsToRoll);
	message_type["offwall"] = JSONValue(MPWantsToJumpOffWall);
	message_type["activeblock"] = JSONValue(MPActiveBlock);

	message_type["blood_damage"] = JSONValue(blood_damage);
	message_type["blood_health"] = JSONValue(blood_health);
	message_type["block_health"] = JSONValue(block_health);
	message_type["temp_health"] = JSONValue(temp_health);
	message_type["permanent_health"] = JSONValue(permanent_health);
	message_type["knocked_out"] = JSONValue(knocked_out);
	message_type["lives"] = JSONValue(lives);
	message_type["blood_amount"] = JSONValue(blood_amount);
	message_type["recovery_time"] = JSONValue(recovery_time);
	message_type["roll_recovery_time"] = JSONValue(roll_recovery_time);
	message_type["ragdoll_type"] = JSONValue(ragdoll_type);
	message_type["blood_delay"] = JSONValue(blood_delay);
	message_type["cut_throat"] = JSONValue(cut_throat);
	message_type["state"] = JSONValue(state);

	char.Execute("MPWantsToRoll = false;");
	char.Execute("MPWantsToJumpOffWall = false;");
	char.Execute("MPActiveBlock = false;");

	message.getRoot()["content"] = message_type;
	SendData(message.writeString(false));
	//Print(message.writeString(false) + "\n");

	//array<string> messages = {"This is the first message", "and another one", "bloop", "soooo", "hmm yeah"};
	//SendData(messages[rand()%messages.size()]);
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

void SendData(string message){
    if( IsValidSocketTCP(socket) )
    {
        Log(info, "Sending data" );
        array<uint8> data;
        for(uint i = 0; i < message.length(); i++){
            data.insertLast(message.substr(i, 1)[0]);
        }
        data.insertLast('\n'[0]);
        Log(info, "Data size " + data.size() );
        SocketTCPSend(socket,data);
    }
    else
    {
		Log(info, "Socket no longer valid");
        socket = SOCKET_ID_INVALID;
		connected_to_server = false;
		trying_to_connect = false;
    }
}

void SendData(array<uint8> message){
    if( IsValidSocketTCP(socket) )
    {
        Log(info, "Sending data" );
        Log(info, "Data size " + message.size() );
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
