#include "ogmp_common.as"

uint connect_try_countdown = 5;
string level_path = "";
string level_name = "";
int player_id = -1;
int initial_sequence_id;
IMGUI@ imGUI;
Chat chat;
Inputfield username_field;
Inputfield address_field;
Inputfield port_field;

int upload_bandwidth = 0;
int download_bandwidth = 0;

enum ClientUIState {
	UsernameUI = 0,
	ServerListUI = 1,
	LevelListUI = 2,
	PlayerListUI = 3,
	CustomAddressUI = 4
}

ClientUIState currentUIState = UsernameUI;

string username = "";
string team = "";
string welcome_message = "";
string character = "";

int ragdoll_counter = 0;

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

bool connected_to_server = false;
bool post_init_run = false;
bool trying_to_connect = false;
bool showing_playerlist = false;
bool cc_ui_added = false;
bool start_adding_cc_ui = false;

float update_timer = 0.0f;
float interval = 1.0f;
int refresh_rate = 30;

bool TCPReceived = false;
bool connected_icon_state = false;

array<RemotePlayer@> remote_players;
IMDivider@ main_divider;
array<uint8>@ data_collection = {};
ServerConnectionInfo@ current_server;
IMDivider@ error_divider;
Dropdown@ dropdown;
string address = "127.0.0.1";
string port = "9000";

void Init(string p_level_name) {
	@imGUI = CreateIMGUI();
	level_path = GetLevelPath();
	level_name = p_level_name;
	imGUI.setHeaderPanels(300, 300);
	imGUI.setFooterHeight(350);
	imGUI.setHeaderHeight(100);
	imGUI.setup();
	imGUI.getHeader().setAlignment(CALeft, CACenter);
	character = character_options[0];
	chat.Initialize();
}

string GetLevelPath(){
	string level_path = GetCurrLevel();
	array<string> separated_path = level_path.split("Data");
	level_path = "Data" + separated_path[1];
	return level_path;
}

bool HandleConnectOnInit(){
	if(StorageHasInt32("ogmp_connect")){
		if(StorageGetInt32("ogmp_connect") == 1){
			StorageSetInt32("ogmp_connect", -1);
			ServerConnectionInfo new_connection(StorageGetString("ogmp_address"), StorageGetInt32("ogmp_port"));
			@current_server = @new_connection;
			server_retriever.online_servers.insertLast(new_connection);
			username = StorageGetString("ogmp_username");
			character = StorageGetString("ogmp_character");
			level_name = StorageGetString("ogmp_level_name");
			trying_to_connect = true;
			return true;
		}else{
			return false;
		}
	}else{
		return false;
	}
}

void IncomingTCPData(uint socket, array<uint8>@ data) {
	download_bandwidth += data.size();
    for( uint i = 0; i < data.length(); i++ ) {
		data_collection.insertLast(data[i]);
    }
}

void ReadServerList(){
	for(uint i = 0; i < server_list.size(); i++){
		if( retriever_socket == SOCKET_ID_INVALID ) {
			retriever_socket = CreateSocketTCP(server_list[i].address, server_list[i].port);
            if( retriever_socket != SOCKET_ID_INVALID ) {
                Log( info, "Connected " + server_list[i].address );
            } else {
                Log( warning, "Unable to connect" );
            }
        }
		if( !IsValidSocketTCP(retriever_socket) ){
			retriever_socket = SOCKET_ID_INVALID;
		}else{
			retriever_socket = SOCKET_ID_INVALID;
		}
	}
}

void ProcessIncomingMessage(array<uint8>@ data){
	uint8 message_type = data[0];
	int data_index = 1;
	/*Log(error, "Incomming message: " + message_type);*/
	if(message_type == SignOn){
		float refresh_rate = GetFloat(data, data_index);
		username = GetString(data, data_index);
		welcome_message = GetString(data, data_index);
		team = GetString(data, data_index);
		character = GetString(data, data_index);
		level_name = GetString(data, data_index);
		connected_to_server = true;
		interval = 1.0 / refresh_rate;

		MovementObject@ player = ReadCharacterID(player_id);
		player.Execute("SwitchCharacter(\"Data/Characters/" + character + ".xml\");");
		chat.AddMessage(welcome_message, "server", true);
		RemoveUI();
		currentUIState = PlayerListUI;
		DisableDebugKeys();
		RemoveAllExceptPlayer();
	}
	else if(message_type == Message){
		string message_source = GetString(data, data_index);
		string message_text = GetString(data, data_index);
		bool notif = GetBool(data, data_index);

		chat.AddMessage(message_text, message_source, notif);
	}
	else if (message_type == SpawnCharacter){
		string username = GetString(data, data_index);
		string team = GetString(data, data_index);
		string character = GetString(data, data_index);
		float pos_x = GetFloat(data, data_index);
		float pos_y = GetFloat(data, data_index);
		float pos_z = GetFloat(data, data_index);
		CreateRemotePlayer(username, team, character, vec3(pos_x, pos_y, pos_z));
	}
	else if (message_type == RemoveCharacter){
		string username = GetString(data, data_index);
		RemoveRemotePlayer(username);
	}
	else if (message_type == UpdateGame){
	}
	else if (message_type == UpdateSelf){
		/*Print("Received updateself" + data.size() + "\n");*/
		MovementObject@ player = ReadCharacterID(player_id);
		while(data_index < int(data.size())){
			PlayerVariableType variable_type = PlayerVariableType(GetInt(data, data_index));
			if(player !is null){
				SetCharacterVariables(player, variable_type, data, data_index, data_index);
			}
		}
	}
	else if (message_type == UpdateCharacter){
		string remote_username = GetString(data, data_index);
		MovementObject@ remote_player = GetRemotePlayer(remote_username);
		if(remote_player !is null){
			while(data_index < int(data.size())){
				PlayerVariableType variable_type = PlayerVariableType(GetInt(data, data_index));
				SetCharacterVariables(remote_player, variable_type, data, data_index, data_index);
			}
		}else{
			Log(error, "Can't find the user!");
		}
	}
	else if (message_type == Error){
		if(cc_ui_added){
			AddError(GetString(data, data_index));
		}else{
			@error_divider = IMDivider("error_divider", DOHorizontal);

			IMContainer container(1000, 50);
			IMDivider divider("holder", DOVertical);
			container.setElement(divider);
			IMText error_message(GetString(data, data_index), error_font);
			divider.append(error_message);
			IMText instruction("Press F12 to start again.", client_connect_font);
			divider.append(instruction);
			//Background
			IMImage background(white_background);
			background.setZOrdering(0);
			background.setSize(vec2(1000, 1000));
			background.setColor(vec4(0,0,0,0.75));
			container.addFloatingElement(background, "background", vec2(0.0f));

			error_divider.append(container);
			imGUI.getMain().setElement(error_divider);
		}
	}
	else if(message_type == LoadPosition){
		MovementObject@ player = ReadCharacterID(player_id);
		PlaySound("Data/Sounds/ambient/amb_canyon_hawk_1.wav");
		player.velocity = vec3(0);
		player.position.x = GetFloat(data, data_index);
		player.position.y = GetFloat(data, data_index);
		player.position.z = GetFloat(data, data_index);
	}
	else if(message_type == ServerInfo){
		string server_name = GetString(data, data_index);
		int nr_players = GetInt(data, data_index);
		server_retriever.SetServerInfo(server_name, nr_players);
	}
	else if(message_type == LevelList){
		array<LevelInfo@> levels;
		while(data_index < int(data.size() - 1)){
			string level_name = GetString(data, data_index);
			string level_path = GetString(data, data_index);
			int nr_players = GetInt(data, data_index);
			levels.insertLast(LevelInfo(level_name, level_path, nr_players));
		}
		server_retriever.SetLevelList(levels);
	}
	else if(message_type == PlayerList){
		array<PlayerInfo@> players;
		while(data_index < int(data.size() - 1)){
			string player_username = GetString(data, data_index);
			string player_character = GetString(data, data_index);
			players.insertLast(PlayerInfo(player_username, player_character));
		}
		server_retriever.SetPlayerList(players);
	}
	else{
		Log(error, "Unknown incomming message: " + message_type);
		/*PrintByteArrayString(data);*/
	}
}

void SetCharacterVariables(MovementObject@ character, PlayerVariableType variable_type, array<uint8>@ data, int &in data_index_in, int &out data_index_out){
	int data_index = data_index_in;
	/*Print("Updating character " + variable_type + "\n");*/
	bool is_player = character.controlled;
	switch (variable_type)
	{
		case blood_damage:{
			if(is_player){
				character.Execute("blood_damage = " + GetFloat(data, data_index) + ";");
			}else{
				character.Execute("MPBloodDamage = " + GetFloat(data, data_index) + ";");
			}
			break;
		}
		case blood_health:{
			if(is_player){
				character.Execute("blood_health = " + GetFloat(data, data_index) + ";");
			}else{
				character.Execute("MPBloodHealth = " + GetFloat(data, data_index) + ";");
			}
			break;
		}
		case block_health:{
			if(is_player){
				character.Execute("block_health = " + GetFloat(data, data_index) + ";");
			}else{
				character.Execute("MPBlockHealth = " + GetFloat(data, data_index) + ";");
			}
			break;
		}
		case temp_health:{
			if(is_player){
				character.Execute("temp_health = " + GetFloat(data, data_index) + ";");
			}else{
				character.Execute("MPTempHealth = " + GetFloat(data, data_index) + ";");
			}
			break;
		}
		case permanent_health:{
			if(is_player){
				character.Execute("permanent_health = " + GetFloat(data, data_index) + ";");
			}else{
				character.Execute("MPPermanentHealth = " + GetFloat(data, data_index) + ";");
			}
			break;
		}
		case blood_amount:{
			if(is_player){
				character.Execute("blood_amount = " + GetFloat(data, data_index) + ";");
			}else{
				character.Execute("MPBloodAmount = " + GetFloat(data, data_index) + ";");
			}
			break;
		}
		case recovery_time:{
			if(is_player){
				character.Execute("recovery_time = " + GetFloat(data, data_index) + ";");
			}else{
				character.Execute("MPRecoveryTime = " + GetFloat(data, data_index) + ";");
			}
			break;
		}
		case roll_recovery_time:{
			if(is_player){
				character.Execute("roll_recovery_time = " + GetFloat(data, data_index) + ";");
			}else{
				character.Execute("MPRollRecoveryTime = " + GetFloat(data, data_index) + ";");
			}
			break;
		}
		case knocked_out:{
			if(is_player){
				character.Execute("knocked_out = " + GetInt(data, data_index) + ";");
			}else{
				character.Execute("MPKnockedOut = " + GetInt(data, data_index) + ";");
			}
			break;
		}
		case ragdoll_type:{
			if(is_player){
				character.Execute("ragdoll_type = " + GetInt(data, data_index) + ";");
			}else{
				character.Execute("MPRagdollType = " + GetInt(data, data_index) + ";");
			}
			break;
		}
		case blood_delay:{
			if(is_player){
				character.Execute("blood_delay = " + GetInt(data, data_index) + ";");
			}else{
				character.Execute("MPBloodDelay = " + GetInt(data, data_index) + ";");
			}
			break;
		}
		case state:{
			if(is_player){
				character.Execute("state = " + GetInt(data, data_index) + ";");
			}else{
				character.Execute("MPState = " + GetInt(data, data_index) + ";");
			}
			break;
		}
		case cut_throat:{
			if(is_player){
				character.Execute("cut_throat = " + GetBool(data, data_index) + ";");
			}else{
				character.Execute("MPCutThroat = " + GetBool(data, data_index) + ";");
			}
			break;
		}
		case remove_blood:{
			bool new_remove_blood = GetBool(data, data_index);
			character.rigged_object().CleanBlood();
		    character.Execute("ClearTemporaryDecals();");
			break;
		}
		case crouch:
			character.Execute("MPWantsToCrouch = " + GetBool(data, data_index) + ";");
			break;
		case jump:
			character.Execute("MPWantsToJump = " + GetBool(data, data_index) + ";");
			break;
		case attack:
			character.Execute("MPWantsToAttack = " + GetBool(data, data_index) + ";");
			break;
		case grab:
			character.Execute("MPWantsToGrab = " + GetBool(data, data_index) + ";");
			break;
		case item:
			character.Execute("MPWantsToItem = " + GetBool(data, data_index) + ";");
			break;
		case drop:
			character.Execute("MPWantsToDrop = " + GetBool(data, data_index) + ";");
			break;
		case position_x:{
			if(is_player){
				character.position.x = GetFloat(data, data_index);
			}else{
				float new_position_x = GetFloat(data, data_index);
				character.position.x = new_position_x;
				/*if(abs(new_position_x - character.position.x) > 1.0f){
				}*/
				character.Execute("MPPositionX = " + new_position_x + ";");
			}
			break;
		}
		case position_y:{
			if(is_player){
				character.position.y = GetFloat(data, data_index);
			}else{
				float new_position_y = GetFloat(data, data_index);
				character.position.y = new_position_y;
				/*if(abs(new_position_y - character.position.y) > 1.0f){
				}*/
				character.Execute("MPPositionY = " + new_position_y + ";");
			}
			break;
		}
		case position_z:{
			if(is_player){
				character.position.z = GetFloat(data, data_index);
			}else{
				float new_position_z = GetFloat(data, data_index);
				character.position.z = new_position_z;
				/*if(abs(new_position_z - character.position.z) > 1.0f){
				}*/
				character.Execute("MPPositionZ = " + new_position_z + ";");
			}
			break;
		}
		case direction_x:{
			character.Execute("dir_x = " + GetFloat(data, data_index) + ";");
			break;
		}
		case direction_z:{
			character.Execute("dir_z = " + GetFloat(data, data_index) + ";");
			break;
		}
		case velocity_x:{
			if(is_player){
				character.velocity.x = GetFloat(data, data_index);
			}else{
				float new_velocity_x = GetFloat(data, data_index);
				//character.velocity.x = new_velocity_x;
				character.Execute("MPVelocityX = " + new_velocity_x + ";");
			}
			break;
		}
		case velocity_y:{
			if(is_player){
				character.velocity.y = GetFloat(data, data_index);
			}else{
				float new_velocity_y = GetFloat(data, data_index);
				//character.velocity.y = new_velocity_y;
				character.Execute("MPVelocityY = " + new_velocity_y + ";");
			}
			break;
		}
		case velocity_z:{
			if(is_player){
				character.velocity.z = GetFloat(data, data_index);
			}else{
				float new_velocity_z = GetFloat(data, data_index);
				//character.velocity.z = new_velocity_z;
				character.Execute("MPVelocityZ = " + new_velocity_z + ";");
			}
			break;
		}
		default:
			break;
	}
	data_index_out = data_index;
}


MovementObject@ GetRemotePlayer(string username){
	for(uint i = 0; i < remote_players.size(); i++){
		if(remote_players[i].username == username){
            if(!ObjectExists(remote_players[i].object_id)){
                return null;
            }
			MovementObject@ found_remote_player = ReadCharacterID(remote_players[i].object_id);
			return found_remote_player;
		}
	}
	return null;
}

void DisableDebugKeys(){
	if(GetConfigValueBool("debug_keys")){
		SetConfigValueBool("debug_keys", false);
		SaveConfig();
		ReloadStaticValues();
	}
}

void CreateRemotePlayer(string username, string team, string character, vec3 position){
	int obj_id = CreateObject("Data/Characters/ogmp/" + character + ".xml");
	remote_players.insertLast(RemotePlayer(username, team, obj_id));
	MovementObject@ remote_player = GetRemotePlayer(username);
	remote_player.Execute("MPUsername = \"" + username + "\";");
	Object@ object = ReadObjectFromID(obj_id);
	ScriptParams@ params = object.GetScriptParams();
	params.SetString("Teams", team);
	remote_player.position = position;
}

void RemoveRemotePlayer(string username){
	for(uint i = 0; i < remote_players.size(); i++){
		MovementObject@ remote_player = ReadCharacterID(remote_players[i].object_id);
        remote_player.Execute("situation.clear();");
		if(remote_players[i].username == username){
			remote_player.Execute("MPRemoveBillboard();");
			DeleteObjectID(remote_players[i].object_id);
			remote_players.removeAt(i);
		}
	}
	MovementObject@ player = ReadCharacterID(player_id);
	player.Execute("situation.clear();");
}

void PrintByteArrayString(array<uint8> data){
	array<string> complete;
    for( uint i = 0; i < data.length(); i++ ) {
        string s('0');
        s[0] = data[i];
        complete.insertLast(s);
		Print(s);
    }
	Print("\n");
}

void PrintByteArray(array<uint8> data){
    for( uint i = 0; i < data.length(); i++ ) {
		Print(data[i] + " ");
    }
	Print("\n");
}

void AddError(string message){
	error_divider.clear();
	IMText error_message(message, error_font);
	error_divider.append(error_message);
}

void DrawGUI() {
	imGUI.render();
}

void AddUI(){
	switch(currentUIState){
		case UsernameUI:
			AddUsernameUI();
			break;
		case ServerListUI:
			AddServerListUI();
			break;
		case CustomAddressUI:
			AddCustomAddressUI();
			break;
		case LevelListUI:
			AddLevelListUI();
			break;
		case PlayerListUI:
			AddPlayerListUI();
			break;
		default:
			DisplayError("UIState", "The UIState is invalid!");
			break;
	}
}

void RemoveUI(){
	cc_ui_added = false;
	level.Execute("has_gui = false;");
	imGUI.getMain().clear();
}

void RefreshUI(){
	RemoveUI();
	AddUI();
}

void AddUsernameUI(){
	cc_ui_added = true;
	level.Execute("has_gui = true;");
	vec2 menu_size(1000, 50);
	vec4 background_color(0,0,0,0.5);
	vec2 button_size(1000, 60);
	vec2 option_size(900, 60);
	vec2 connect_button_size(1000, 60);
	float button_size_offset = 10.0f;
	float description_width = 200.0f;

	IMContainer menu_container(menu_size.x, menu_size.y);
	menu_container.setAlignment(CACenter, CATop);
	IMDivider menu_divider("menu_divider", DOVertical);
	menu_container.setElement(menu_divider);

	menu_divider.appendSpacer(10);

	{
		//Choose a username and character
		IMContainer container(button_size.x, button_size.y);
		menu_divider.append(container);
		IMDivider divider("title_divider", DOHorizontal);
		divider.setZOrdering(4);
		container.setElement(divider);
		IMText title("Choose a username and character.", client_connect_font);
		divider.append(title);
		//Background
		IMImage background(brushstroke_background);
		background.setZOrdering(2);
		background.setClip(false);
		background.setSize(vec2(600, 60));
		background.setAlpha(0.85f);
		container.addFloatingElement(background, "background", vec2(container.getSizeX() / 2.0f - background.getSizeX() / 2.0f,0));
	}

	menu_divider.appendSpacer(10);

	{
		//Username input field.
		IMContainer username_container(option_size.x, option_size.y);
		IMDivider username_divider("username_divider", DOHorizontal);
		IMContainer username_parent_container(button_size.x / 2.0f, button_size.y);
		username_parent_container.sendMouseOverToChildren(true);
		username_parent_container.sendMouseDownToChildren(true);
		IMDivider username_parent("username_parent", DOHorizontal);
		username_parent_container.setElement(username_parent);
		username_container.setElement(username_divider);
		username_parent_container.addLeftMouseClickBehavior(IMFixedMessageOnClick("activate_username_field"), "");

		IMContainer description_container(description_width, option_size.y);
		IMText description_label("Username: ", client_connect_font);
		description_container.setElement(description_label);
		description_label.setZOrdering(3);
		username_divider.append(description_container);

		username_divider.appendSpacer(25);

		IMText username_label(username, client_connect_font);
		username_label.addMouseOverBehavior(mouseover_fontcolor, "");
		username_label.setZOrdering(3);
		username_parent.append(username_label);
		username_divider.append(username_parent_container);

		IMImage username_background(white_background);
		username_background.setZOrdering(0);
		username_background.setSize(500 - button_size_offset);
		username_background.setColor(vec4(0,0,0,0.75));
		username_parent_container.addFloatingElement(username_background, "username_background", vec2(button_size_offset / 2.0f));

		username_field.SetInputField(@username_label, @username_parent, "username");
		menu_divider.append(username_container);
	}

	{
		//Character dropdown.
		IMContainer container(option_size.x, option_size.y);
		IMDivider divider("character_divider", DOHorizontal);
		container.setElement(divider);

		IMContainer parent_container(button_size.x / 2.0f, button_size.y);
		// parent_container.sendMouseOverToChildren(true);
		// parent_container.sendMouseDownToChildren(true);
		IMDivider parent_divider("username_parent", DOHorizontal);
		parent_container.setElement(parent_divider);

		IMContainer description_container(description_width, option_size.y);
		IMText label("Character: ", client_connect_font);
		description_container.setElement(label);
		label.setZOrdering(3);
		divider.append(description_container);

		divider.appendSpacer(25);

		IMText character_label("", client_connect_font);
		character_label.setZOrdering(3);
		parent_divider.append(character_label);
		divider.append(parent_container);

		Dropdown new_dropdown(character_options, character_names, character, parent_container);
		@dropdown = @new_dropdown;

		menu_divider.append(container);
	}

	menu_divider.appendSpacer(20);

	//The button container at the bottom of the UI.
	IMContainer button_container(connect_button_size.x, connect_button_size.y);
	button_container.setAlignment(CARight, CACenter);
	IMDivider button_divider("button_divider", DOHorizontal);
	button_container.setElement(button_divider);
	menu_divider.append(button_container);

	{
		//The next button
		IMContainer next_button_container(200, connect_button_size.y);
		next_button_container.sendMouseOverToChildren(true);
		next_button_container.sendMouseDownToChildren(true);
		next_button_container.setAlignment(CACenter, CACenter);
		IMDivider next_button_divider("next_button_divider", DOHorizontal);
		next_button_divider.setZOrdering(4);
		next_button_container.setElement(next_button_divider);
		IMText next_button("Next", client_connect_font);
		next_button.addMouseOverBehavior(mouseover_fontcolor, "");
		next_button_divider.append(next_button);

		IMImage next_button_background(white_background);
		next_button_background.setZOrdering(0);
		next_button_background.setSize(vec2(200 - button_size_offset, connect_button_size.y - button_size_offset));
		next_button_background.setColor(vec4(0,0,0,0.75));
		next_button_container.addFloatingElement(next_button_background, "next_button_background", vec2(button_size_offset / 2.0f));

		next_button_container.addLeftMouseClickBehavior(IMFixedMessageOnClick("next_ui"), "");
		button_divider.append(next_button_container);
	}

	//The main background
	IMImage background(white_background);
	background.addLeftMouseClickBehavior(IMFixedMessageOnClick("close_all"), "");
	background.setColor(background_color);
	background.setSize(vec2(menu_size.x, 1000));
	menu_container.addFloatingElement(background, "background", vec2(0));
	imGUI.getMain().setSize(vec2(2560, 1000));
	imGUI.getMain().setElement(menu_container);
}

void AddServerListUI(){
	cc_ui_added = true;
	level.Execute("has_gui = true;");
	vec2 menu_size(1000, 50);
	vec4 background_color(0,0,0,0.5);
	vec2 connect_button_size(1000, 60);
	float button_size_offset = 10.0f;
	int server_name_width = 500;
	int latency_width = 200;
	int nr_players_width = 200;

	server_retriever.CheckOnlineServers();

	IMContainer menu_container(menu_size.x, menu_size.y);
	menu_container.setAlignment(CACenter, CATop);
	IMDivider menu_divider("menu_divider", DOVertical);
	menu_container.setElement(menu_divider);

	menu_divider.appendSpacer(10);

	//Pick a server titlebar
	IMContainer pick_server_container(connect_button_size.x, connect_button_size.y);
	menu_divider.append(pick_server_container);
	IMDivider pick_server_divider("pick_server_divider", DOHorizontal);
	pick_server_divider.setZOrdering(4);
	pick_server_container.setElement(pick_server_divider);
	IMText pick_server("Pick a server", client_connect_font);
	pick_server_divider.append(pick_server);

	//Custom address button
	IMImage custom_address_image(custom_address_icon);
	custom_address_image.scaleToSizeY(50);
	pick_server_container.addFloatingElement(custom_address_image, "custom_address_image", vec2(button_size_offset / 2.0f), 0);
	custom_address_image.setColor(client_connect_font_small.color);
	custom_address_image.addMouseOverBehavior(mouseover_fontcolor, "");
	custom_address_image.addLeftMouseClickBehavior(IMFixedMessageOnClick("custom_address"), "");

	//Title background
	IMImage pick_server_background(brushstroke_background);
	pick_server_background.setZOrdering(2);
	pick_server_background.setClip(false);
	pick_server_background.setSize(vec2(500, 60));
	pick_server_background.setAlpha(0.85f);
	pick_server_container.addFloatingElement(pick_server_background, "pick_server_background", vec2(pick_server_container.getSizeX() / 2.0f - pick_server_background.getSizeX() / 2.0f,0));

	//Server browser titlebar
	IMContainer titlebar_container(connect_button_size.x, connect_button_size.y);
	menu_divider.append(titlebar_container);
	IMDivider titlebar_divider("titlebar_divider", DOHorizontal);
	titlebar_divider.setZOrdering(4);
	titlebar_container.setElement(titlebar_divider);

	IMContainer servername_label_container(server_name_width);
	IMText servername_label("Server name", client_connect_font);
	servername_label.setZOrdering(4);
	servername_label_container.setElement(servername_label);
	titlebar_divider.append(servername_label_container);

	IMContainer latency_label_container(latency_width);
	IMText latency_label("Latency", client_connect_font);
	latency_label.setZOrdering(4);
	latency_label_container.setElement(latency_label);
	titlebar_divider.append(latency_label_container);

	IMContainer nr_players_label_container(nr_players_width);
	IMText nr_players_label("Nr players", client_connect_font);
	nr_players_label.setZOrdering(4);
	nr_players_label_container.setElement(nr_players_label);
	titlebar_divider.append(nr_players_label_container);

	for(uint i = 0; i < server_retriever.online_servers.size(); i++){
		//Connect button
		IMContainer button_container(connect_button_size.x, connect_button_size.y);
		button_container.sendMouseOverToChildren(true);
		IMDivider button_divider("button_divider", DOHorizontal);
		button_container.setElement(button_divider);

		button_container.addLeftMouseClickBehavior(IMFixedMessageOnClick("server_chosen", i), "");
		menu_divider.append(button_container);

		//The server name
		IMContainer servername_container(server_name_width);
		IMText server_name(server_retriever.online_servers[i].server_name, client_connect_font_small);
		server_name.setZOrdering(4);
		server_name.addMouseOverBehavior(mouseover_fontcolor, "");
		servername_container.setElement(server_name);
		button_divider.append(servername_container);

		//The latency
		IMContainer latency_container(latency_width);
		IMText latency(server_retriever.online_servers[i].latency + " ms", client_connect_font_small);
		latency.setZOrdering(4);
		latency.addMouseOverBehavior(mouseover_fontcolor, "");
		latency_container.setElement(latency);
		button_divider.append(latency_container);

		//The number of players
		IMContainer nr_players_container(nr_players_width);
		IMText nr_players(server_retriever.online_servers[i].nr_players + "", client_connect_font_small);
		nr_players.setZOrdering(4);
		nr_players.addMouseOverBehavior(mouseover_fontcolor, "");
		nr_players_container.setElement(nr_players);
		button_divider.append(nr_players_container);

		IMImage button_background(white_background);
		button_background.setZOrdering(0);
		button_background.setSize(connect_button_size - button_size_offset);
		button_background.setColor(vec4(0,0,0,0.75));
		button_container.addFloatingElement(button_background, "button_background", vec2(button_size_offset / 2.0f));
	}

	IMDivider info_divider("info_divider", DOHorizontal);
	menu_divider.append(info_divider);
	if(server_retriever.checking_servers){
		IMText info("Getting more servers...", client_connect_font_small);
		info_divider.append(info);
	}else if(server_retriever.online_servers.size() == 0){
		IMText info("No online servers found.", client_connect_font_small);
		info_divider.append(info);
	}

	//The errors are put in this divider
	@error_divider = IMDivider("error_divider", DOVertical);
	menu_divider.append(error_divider);

	menu_divider.appendSpacer(20);

	//The button container at the bottom of the UI.
	IMContainer button_container(connect_button_size.x, connect_button_size.y);
	button_container.setAlignment(CALeft, CACenter);
	IMDivider button_divider("button_divider", DOHorizontal);
	button_container.setElement(button_divider);
	menu_divider.append(button_container);

	{
		//The previous button
		IMContainer previous_button_container(200, connect_button_size.y);
		previous_button_container.sendMouseOverToChildren(true);
		previous_button_container.sendMouseDownToChildren(true);
		previous_button_container.setAlignment(CACenter, CACenter);
		IMDivider previous_button_divider("previous_button_divider", DOHorizontal);
		previous_button_divider.setZOrdering(4);
		previous_button_container.setElement(previous_button_divider);
		IMText previous_button("Previous", client_connect_font);
		previous_button.addMouseOverBehavior(mouseover_fontcolor, "");
		previous_button_divider.append(previous_button);

		IMImage previous_button_background(white_background);
		previous_button_background.setZOrdering(0);
		previous_button_background.setSize(vec2(200 - button_size_offset, connect_button_size.y - button_size_offset));
		previous_button_background.setColor(vec4(0,0,0,0.75));
		previous_button_container.addFloatingElement(previous_button_background, "previous_button_background", vec2(button_size_offset / 2.0f));

		previous_button_container.addLeftMouseClickBehavior(IMFixedMessageOnClick("previous_ui"), "");
		button_divider.append(previous_button_container);
	}

	//The main background
	IMImage background(white_background);
	background.setColor(background_color);
	background.setSize(vec2(menu_size.x, 1000));
	menu_container.addFloatingElement(background, "background", vec2(0));
	imGUI.getMain().setSize(vec2(2560, 1000));
	/*imGUI.getMain().setAlignment(CACenter, CACenter);*/
	imGUI.getMain().setElement(menu_container);
}

void AddCustomAddressUI(){
	cc_ui_added = true;
	level.Execute("has_gui = true;");
	vec2 menu_size(1000, 50);
	vec4 background_color(0,0,0,0.5);
	vec2 connect_button_size(1000, 60);
	float button_size_offset = 10.0f;
	int server_name_width = 500;
	int latency_width = 200;
	int nr_players_width = 200;
	vec2 option_size(900, 60);
	vec2 button_size(1000, 60);
	float description_width = 200.0f;

	IMContainer menu_container(menu_size.x, menu_size.y);
	menu_container.setAlignment(CACenter, CATop);
	IMDivider menu_divider("menu_divider", DOVertical);
	menu_container.setElement(menu_divider);

	menu_divider.appendSpacer(10);

	//Custom address titlebar
	IMContainer custom_address_container(connect_button_size.x, connect_button_size.y);
	menu_divider.append(custom_address_container);
	IMDivider custom_address_divider("custom_address_divider", DOHorizontal);
	custom_address_divider.setZOrdering(4);
	custom_address_container.setElement(custom_address_divider);
	IMText pick_server("Pick address and port", client_connect_font);
	custom_address_divider.append(pick_server);
	//Title background
	IMImage custom_address_background(brushstroke_background);
	custom_address_background.setZOrdering(2);
	custom_address_background.setClip(false);
	custom_address_background.setSize(vec2(500, 60));
	custom_address_background.setAlpha(0.85f);
	custom_address_container.addFloatingElement(custom_address_background, "custom_address_background", vec2(custom_address_container.getSizeX() / 2.0f - custom_address_background.getSizeX() / 2.0f,0));

	{
		//address input field.
		IMContainer address_container(option_size.x, option_size.y);
		IMDivider address_divider("address_divider", DOHorizontal);
		IMContainer address_parent_container(button_size.x / 2.0f, button_size.y);
		address_parent_container.sendMouseOverToChildren(true);
		address_parent_container.sendMouseDownToChildren(true);
		IMDivider address_parent("address_parent", DOHorizontal);
		address_parent_container.setElement(address_parent);
		address_container.setElement(address_divider);
		address_parent_container.addLeftMouseClickBehavior(IMFixedMessageOnClick("activate_address_field"), "");

		IMContainer description_container(description_width, option_size.y);
		IMText description_label("Address: ", client_connect_font);
		description_container.setElement(description_label);
		description_label.setZOrdering(3);
		address_divider.append(description_container);

		address_divider.appendSpacer(25);

		IMText address_label(address, client_connect_font);
		address_label.addMouseOverBehavior(mouseover_fontcolor, "");
		address_label.setZOrdering(3);
		address_parent.append(address_label);
		address_divider.append(address_parent_container);

		IMImage address_background(white_background);
		address_background.setZOrdering(0);
		address_background.setSize(500 - button_size_offset);
		address_background.setColor(vec4(0,0,0,0.75));
		address_parent_container.addFloatingElement(address_background, "address_background", vec2(button_size_offset / 2.0f));

		address_field.SetInputField(@address_label, @address_parent, "address");
		menu_divider.append(address_container);
	}

	{
		//port input field.
		IMContainer port_container(option_size.x, option_size.y);
		IMDivider port_divider("port_divider", DOHorizontal);
		IMContainer port_parent_container(button_size.x / 2.0f, button_size.y);
		port_parent_container.sendMouseOverToChildren(true);
		port_parent_container.sendMouseDownToChildren(true);
		IMDivider port_parent("port_parent", DOHorizontal);
		port_parent_container.setElement(port_parent);
		port_container.setElement(port_divider);
		port_parent_container.addLeftMouseClickBehavior(IMFixedMessageOnClick("activate_port_field"), "");

		IMContainer description_container(description_width, option_size.y);
		IMText description_label("Port: ", client_connect_font);
		description_container.setElement(description_label);
		description_label.setZOrdering(3);
		port_divider.append(description_container);

		port_divider.appendSpacer(25);

		IMText port_label(port, client_connect_font);
		port_label.addMouseOverBehavior(mouseover_fontcolor, "");
		port_label.setZOrdering(3);
		port_parent.append(port_label);
		port_divider.append(port_parent_container);

		IMImage port_background(white_background);
		port_background.setZOrdering(0);
		port_background.setSize(500 - button_size_offset);
		port_background.setColor(vec4(0,0,0,0.75));
		port_parent_container.addFloatingElement(port_background, "port_background", vec2(button_size_offset / 2.0f));

		port_field.SetInputField(@port_label, @port_parent, "port");
		menu_divider.append(port_container);
	}

	menu_divider.appendSpacer(20);
	//The errors are put in this divider
	@error_divider = IMDivider("error_divider", DOVertical);
	menu_divider.append(error_divider);

	{
		menu_divider.appendSpacer(20);

		//The button container at the bottom of the UI.
		IMContainer button_container(connect_button_size.x, connect_button_size.y);
		button_container.setAlignment(CALeft, CACenter);
		IMDivider button_divider("button_divider", DOHorizontal);
		button_container.setElement(button_divider);
		menu_divider.append(button_container);

		{
			//The previous button
			IMContainer previous_button_container(200, connect_button_size.y);
			previous_button_container.sendMouseOverToChildren(true);
			previous_button_container.sendMouseDownToChildren(true);
			previous_button_container.setAlignment(CACenter, CACenter);
			IMDivider previous_button_divider("previous_button_divider", DOHorizontal);
			previous_button_divider.setZOrdering(4);
			previous_button_container.setElement(previous_button_divider);
			IMText previous_button("Previous", client_connect_font);
			previous_button.addMouseOverBehavior(mouseover_fontcolor, "");
			previous_button_divider.append(previous_button);

			IMImage previous_button_background(white_background);
			previous_button_background.setZOrdering(0);
			previous_button_background.setSize(vec2(200 - button_size_offset, connect_button_size.y - button_size_offset));
			previous_button_background.setColor(vec4(0,0,0,0.75));
			previous_button_container.addFloatingElement(previous_button_background, "previous_button_background", vec2(button_size_offset / 2.0f));

			previous_button_container.addLeftMouseClickBehavior(IMFixedMessageOnClick("previous_ui"), "");
			button_divider.append(previous_button_container);
		}
		button_divider.appendSpacer(connect_button_size.x - (200 * 2.0f));
		{
			//The next button
			IMContainer next_button_container(200, connect_button_size.y);
			next_button_container.sendMouseOverToChildren(true);
			next_button_container.sendMouseDownToChildren(true);
			next_button_container.setAlignment(CACenter, CACenter);
			IMDivider next_button_divider("next_button_divider", DOHorizontal);
			next_button_divider.setZOrdering(4);
			next_button_container.setElement(next_button_divider);
			IMText next_button("Next", client_connect_font);
			next_button.addMouseOverBehavior(mouseover_fontcolor, "");
			next_button_divider.append(next_button);

			IMImage next_button_background(white_background);
			next_button_background.setZOrdering(0);
			next_button_background.setSize(vec2(200 - button_size_offset, connect_button_size.y - button_size_offset));
			next_button_background.setColor(vec4(0,0,0,0.75));
			next_button_container.addFloatingElement(next_button_background, "next_button_background", vec2(button_size_offset / 2.0f));

			next_button_container.addLeftMouseClickBehavior(IMFixedMessageOnClick("check_custom_address"), "");
			button_divider.append(next_button_container);
		}
	}

	//The main background
	IMImage background(white_background);
	background.addLeftMouseClickBehavior(IMFixedMessageOnClick("close_all"), "");
	background.setColor(background_color);
	background.setSize(vec2(menu_size.x, 1000));
	menu_container.addFloatingElement(background, "background", vec2(0));
	imGUI.getMain().setSize(vec2(2560, 1000));
	imGUI.getMain().setElement(menu_container);
}

void AddLevelListUI(){
	cc_ui_added = true;
	level.Execute("has_gui = true;");
	vec2 menu_size(1000, 50);
	vec4 background_color(0,0,0,0.5);
	vec2 connect_button_size(1000, 60);
	float button_size_offset = 10.0f;
	int level_name_width = 500;
	int nr_players_width = 200;

	server_retriever.GetLevelList();

	IMContainer menu_container(menu_size.x, menu_size.y);
	menu_container.setAlignment(CACenter, CATop);
	IMDivider menu_divider("menu_divider", DOVertical);
	menu_container.setElement(menu_divider);

	menu_divider.appendSpacer(10);

	//Pick a level titlebar
	IMContainer pick_level_container(connect_button_size.x, connect_button_size.y);
	menu_divider.append(pick_level_container);
	IMDivider pick_level_divider("pick_level_divider", DOHorizontal);
	pick_level_divider.setZOrdering(4);
	pick_level_container.setElement(pick_level_divider);
	IMText pick_server("Pick a level", client_connect_font);
	pick_level_divider.append(pick_server);
	//Title background
	IMImage pick_level_background(brushstroke_background);
	pick_level_background.setZOrdering(2);
	pick_level_background.setClip(false);
	pick_level_background.setSize(vec2(500, 60));
	pick_level_background.setAlpha(0.85f);
	pick_level_container.addFloatingElement(pick_level_background, "pick_level_background", vec2(pick_level_container.getSizeX() / 2.0f - pick_level_background.getSizeX() / 2.0f,0));

	//Server browser titlebar
	IMContainer titlebar_container(connect_button_size.x, connect_button_size.y);
	menu_divider.append(titlebar_container);
	IMDivider titlebar_divider("titlebar_divider", DOHorizontal);
	titlebar_divider.setZOrdering(3);
	titlebar_container.setElement(titlebar_divider);

	IMContainer levelname_label_container(level_name_width);
	IMText levelname_label("Level name", client_connect_font);
	levelname_label.setZOrdering(3);
	levelname_label_container.setElement(levelname_label);
	titlebar_divider.append(levelname_label_container);

	IMContainer nr_players_label_container(nr_players_width);
	IMText nr_players_label("Nr players", client_connect_font);
	nr_players_label.setZOrdering(3);
	nr_players_label_container.setElement(nr_players_label);
	titlebar_divider.append(nr_players_label_container);

	bool server_includes_this_level = false;
	for(uint i = 0; i < current_server.levels.size(); i++){
		if(current_server.levels[i].level_path == level_path){
			server_includes_this_level = true;
		}
	}
	if(!server_includes_this_level){
		//Add the current level always to the top of the list.
		IMContainer button_container(connect_button_size.x, connect_button_size.y);
		button_container.sendMouseOverToChildren(true);
		IMDivider button_divider("button_divider", DOHorizontal);
		button_container.setElement(button_divider);

		IMMessage level_chosen("level_chosen");
		level_chosen.addString(level_name);
		level_chosen.addString(level_path);

		button_container.addLeftMouseClickBehavior(IMFixedMessageOnClick(level_chosen), "");
		menu_divider.append(button_container);

		//The level name
		IMContainer levelname_container(level_name_width);
		IMText level_name_label("Current level: " + level_name, client_connect_font_small);
		level_name_label.setZOrdering(4);
		level_name_label.addMouseOverBehavior(mouseover_fontcolor, "");
		levelname_container.setElement(level_name_label);
		button_divider.append(levelname_container);

		//The number of players
		IMContainer nr_players_container(nr_players_width);
		IMText nr_players("0", client_connect_font_small);
		nr_players.setZOrdering(4);
		nr_players.addMouseOverBehavior(mouseover_fontcolor, "");
		nr_players_container.setElement(nr_players);
		button_divider.append(nr_players_container);

		IMImage button_background(white_background);
		button_background.setZOrdering(0);
		button_background.setSize(connect_button_size - button_size_offset);
		button_background.setColor(vec4(0,0,0,0.75));
		button_container.addFloatingElement(button_background, "button_background", vec2(button_size_offset / 2.0f));
	}

	{
		for(uint i = 0; i < current_server.levels.size(); i++){
			IMContainer button_container(connect_button_size.x, connect_button_size.y);
			button_container.sendMouseOverToChildren(true);
			IMDivider button_divider("button_divider", DOHorizontal);
			button_container.setElement(button_divider);

			IMMessage level_chosen("level_chosen");
			level_chosen.addString(current_server.levels[i].level_name);
			level_chosen.addString(current_server.levels[i].level_path);

			button_container.addLeftMouseClickBehavior(IMFixedMessageOnClick(level_chosen), "");
			menu_divider.append(button_container);

			//The level name
			IMContainer levelname_container(level_name_width);
			IMText level_name_label("", client_connect_font_small);
			if(current_server.levels[i].level_path == level_path){
				level_name_label.setText("Current level: " + current_server.levels[i].level_name);
			}else{
				level_name_label.setText(current_server.levels[i].level_name);
			}
			level_name_label.setZOrdering(4);
			level_name_label.addMouseOverBehavior(mouseover_fontcolor, "");
			levelname_container.setElement(level_name_label);
			button_divider.append(levelname_container);

			//The number of players
			IMContainer nr_players_container(nr_players_width);
			IMText nr_players(current_server.levels[i].nr_players + "", client_connect_font_small);
			nr_players.setZOrdering(4);
			nr_players.addMouseOverBehavior(mouseover_fontcolor, "");
			nr_players_container.setElement(nr_players);
			button_divider.append(nr_players_container);

			IMImage button_background(white_background);
			button_background.setZOrdering(0);
			button_background.setSize(connect_button_size - button_size_offset);
			button_background.setColor(vec4(0,0,0,0.75));
			button_container.addFloatingElement(button_background, "button_background", vec2(button_size_offset / 2.0f));
		}
	}

	menu_divider.appendSpacer(20);

	//The button container at the bottom of the UI.
	IMContainer button_container(connect_button_size.x, connect_button_size.y);
	button_container.setAlignment(CALeft, CACenter);
	IMDivider button_divider("button_divider", DOHorizontal);
	button_container.setElement(button_divider);
	menu_divider.append(button_container);

	{
		//The previous button
		IMContainer previous_button_container(200, connect_button_size.y);
		previous_button_container.sendMouseOverToChildren(true);
		previous_button_container.sendMouseDownToChildren(true);
		previous_button_container.setAlignment(CACenter, CACenter);
		IMDivider previous_button_divider("previous_button_divider", DOHorizontal);
		previous_button_divider.setZOrdering(4);
		previous_button_container.setElement(previous_button_divider);
		IMText previous_button("Previous", client_connect_font);
		previous_button.addMouseOverBehavior(mouseover_fontcolor, "");
		previous_button_divider.append(previous_button);

		IMImage previous_button_background(white_background);
		previous_button_background.setZOrdering(0);
		previous_button_background.setSize(vec2(200 - button_size_offset, connect_button_size.y - button_size_offset));
		previous_button_background.setColor(vec4(0,0,0,0.75));
		previous_button_container.addFloatingElement(previous_button_background, "previous_button_background", vec2(button_size_offset / 2.0f));

		previous_button_container.addLeftMouseClickBehavior(IMFixedMessageOnClick("previous_ui"), "");
		button_divider.append(previous_button_container);
	}

	//The errors are put in this divider
	@error_divider = IMDivider("error_divider", DOVertical);
	menu_divider.append(error_divider);

	//The main background
	IMImage background(white_background);
	background.setColor(background_color);
	background.setSize(vec2(menu_size.x, 1000));
	menu_container.addFloatingElement(background, "background", vec2(0));
	imGUI.getMain().setSize(vec2(2560, 1000));
	/*imGUI.getMain().setAlignment(CACenter, CACenter);*/
	imGUI.getMain().setElement(menu_container);
}

void AddPlayerListUI(){
	cc_ui_added = true;
	level.Execute("has_gui = true;");
	vec2 menu_size(1000, 50);
	vec4 background_color(0,0,0,0.5);
	vec2 connect_button_size(1000, 60);
	float button_size_offset = 10.0f;
	int player_name_width = 500;
	int player_character_width = 200;

	server_retriever.GetPlayerList();

	IMContainer menu_container(menu_size.x, menu_size.y);
	menu_container.setAlignment(CACenter, CATop);
	IMDivider menu_divider("menu_divider", DOVertical);
	menu_container.setElement(menu_divider);

	menu_divider.appendSpacer(10);

	{
		//Choose a username and character
		IMContainer container(connect_button_size.x, connect_button_size.y);
		menu_divider.append(container);
		IMDivider divider("title_divider", DOHorizontal);
		divider.setZOrdering(4);
		container.setElement(divider);
		IMText title("Player List.", client_connect_font);
		divider.append(title);
		//Background
		IMImage background(brushstroke_background);
		background.setZOrdering(2);
		background.setClip(false);
		background.setSize(vec2(300, 60));
		background.setAlpha(0.85f);
		container.addFloatingElement(background, "background", vec2(container.getSizeX() / 2.0f - background.getSizeX() / 2.0f,0));
	}

	//Player list titlebar
	IMContainer titlebar_container(connect_button_size.x, connect_button_size.y);
	menu_divider.append(titlebar_container);
	IMDivider titlebar_divider("titlebar_divider", DOHorizontal);
	titlebar_divider.setZOrdering(3);
	titlebar_container.setElement(titlebar_divider);

	IMContainer name_label_container(player_name_width);
	IMText name_label("Player name", client_connect_font);
	name_label.setZOrdering(3);
	name_label_container.setElement(name_label);
	titlebar_divider.append(name_label_container);

	IMContainer character_label_container(player_character_width);
	IMText character_label("Player character", client_connect_font);
	character_label.setZOrdering(3);
	character_label_container.setElement(character_label);
	titlebar_divider.append(character_label_container);

	menu_divider.appendSpacer(10);

	for(uint i = 0; i < current_server.players.size(); i++){
		IMContainer container(connect_button_size.x, connect_button_size.y);
		IMDivider button_divider("button_divider", DOHorizontal);
		container.setElement(button_divider);

		menu_divider.append(container);

		//The player username
		IMContainer playername_container(player_name_width);
		IMText player_name_label(current_server.players[i].player_username, client_connect_font_small);
		player_name_label.setZOrdering(4);
		playername_container.setElement(player_name_label);
		button_divider.append(playername_container);

		//The player character
		IMContainer player_character_container(player_character_width);
		int character_name_index = character_options.find(current_server.players[i].player_character);
		IMText player_character_label("", client_connect_font_small);
		if(character_name_index != -1){
			player_character_label.setText(character_names[character_name_index]);
		}else{
			player_character_label.setText(current_server.players[i].player_character);
		}
		player_character_label.setZOrdering(4);
		player_character_container.setElement(player_character_label);
		button_divider.append(player_character_container);

		IMImage button_background(white_background);
		button_background.setZOrdering(0);
		button_background.setSize(connect_button_size - button_size_offset);
		button_background.setColor(vec4(0,0,0,0.75));
		container.addFloatingElement(button_background, "button_background", vec2(button_size_offset / 2.0f));
	}

	menu_divider.appendSpacer(20);

	if(connected_to_server){
		//Disconnect button
		IMContainer button_container(connect_button_size.x, connect_button_size.y);
		button_container.addLeftMouseClickBehavior(IMFixedMessageOnClick("disconnect"), "");
		menu_divider.append(button_container);

		IMText connect_text("Disconnect from server.", client_connect_font);
		connect_text.addMouseOverBehavior(mouseover_fontcolor, "");
		connect_text.setZOrdering(3);
		button_container.setElement(connect_text);

		IMImage button_background(white_background);
		button_background.setZOrdering(0);
		button_background.setSize(connect_button_size - button_size_offset);
		button_background.setColor(vec4(0,0,0,0.75));
		button_container.addFloatingElement(button_background, "button_background", vec2(button_size_offset / 2.0f));
	}
	//The errors are put in this divider
	@error_divider = IMDivider("error_divider", DOVertical);
	menu_divider.append(error_divider);

	//The main background
	IMImage background(white_background);
	background.setColor(background_color);
	background.setSize(vec2(menu_size.x, 1000));
	menu_container.addFloatingElement(background, "background", vec2(0));
	imGUI.getMain().setSize(vec2(2560, 1000));
	/*imGUI.getMain().setAlignment(CACenter, CACenter);*/
	imGUI.getMain().setElement(menu_container);
}

void PostInit(){
	player_id = GetPlayerCharacterID();
	bool auto_connected = HandleConnectOnInit();
	if(!auto_connected){
		//Create a random username from an adjactive and a noun.
		username = adjectives[rand() % adjectives.length()] + nouns[rand() % nouns.length()];
	}
	SetupPlayerVariables();
}

void Update(int paused) {
	server_retriever.Update();
	UpdateConnectedIcon();
	UpdateBandwidth();
	username_field.Update();
	address_field.Update();
	port_field.Update();
	if(!post_init_run){
		PostInit();
		post_init_run = true;
	}
	if(player_id == -1){
		player_id = GetPlayerCharacterID();
		SetupPlayerVariables();
		return;
	}else if(!ObjectExists(player_id)){
        player_id = -1;
        return;
    }
    if(connected_to_server){
		/*UpdateTimeCriticalPlayerVariables();*/
		update_timer += time_step;
		if(update_timer > interval){
	        SendPlayerUpdate();
			update_timer = 0;
	    }
		KeyChecks();
		UpdatePlayerUsernameBillboard();
    }else{
        PreConnectedKeyChecks();
        ConnectToServer();
    }
	// process any messages produced from the update
    while( imGUI.getMessageQueueSize() > 0 ) {
        IMMessage@ message = imGUI.getNextMessage();
		Log( info, "Got processMessage " + message.name );
		if( message.name == "" ){return;}
		else if( message.name == "server_chosen" ){
			int index = message.getInt(0);
			@current_server = server_retriever.online_servers[index];
			NextUIState();
	        RefreshUI();
		}
		else if( message.name == "check_custom_address" ){
			ServerConnectionInfo custom_address(address, parseInt(port));
			@current_server = custom_address;
			server_retriever.checking_custom_address = true;
		}
		else if( message.name == "level_chosen" ){
			HandleLevelChosen(message.getString(0), message.getString(1));
		}
		else if( message.name == "previous_ui" ){
			PreviousUIState();
			RefreshUI();
		}
		else if( message.name == "next_ui" ){
			NextUIState();
			RefreshUI();
		}
		else if( message.name == "disconnect" ){
			DisconnectFromServer();
			RemoveUI();
		}
		else if( message.name == "activate_username_field" ){
			username_field.Activate();
			dropdown.SetNewValue(character);
			dropdown.Deactivate();
		}
		else if( message.name == "activate_address_field" ){
			if(port_field.active){
				port_field.Deactivate();
			}
			address_field.Activate();
		}
		else if( message.name == "activate_port_field" ){
			if(address_field.active){
				address_field.Deactivate();
			}
			port_field.Activate();
		}
		else if( message.name == "activate_dropdown" ){
			if(username_field.active){
				username_field.Deactivate();
			}
			dropdown.Activate();
		}
		else if( message.name == "close_all" ){
			if(username_field.active){
				username_field.Deactivate();
			}
			if(address_field.active){
				address_field.Deactivate();
			}
			if(port_field.active){
				port_field.Deactivate();
			}
			dropdown.Deactivate();
		}
		else if( message.name == "option_chosen" ){
			character = message.getString(0);
			dropdown.SetNewValue(character);
			dropdown.Deactivate();
		}
		else if( message.name == "custom_address" ){
			RemoveUI();
			currentUIState++;
			AddCustomAddressUI();
		}
		else if( message.name == "update_value" ){
			string value_name = message.getString(0);
			if(value_name == "username"){
				username = message.getString(1);
			}
			else if(value_name == "address"){
				address = message.getString(1);
			}
			else if(value_name == "port"){
				port = message.getString(1);
			}
		}
	}
	SeparateMessages();
	if(connected_to_server){
		UpdateInput();
	}
	imGUI.update();
}

void UpdatePlayerUsernameBillboard(){
	MovementObject@ player = ReadCharacterID(player_id);
	vec3 draw_offset = vec3(0.0f, 1.25f, 0.0f);
	DebugDrawText(player.position + draw_offset, username, 50.0f, false, _delete_on_update);
}

void NextUIState(){
	if(currentUIState != PlayerListUI){
		currentUIState++;
		server_retriever.ResetGetters();
	}
}

void PreviousUIState(){
	if(currentUIState != 0){
		currentUIState--;
		server_retriever.ResetGetters();
	}
}

void UpdateConnectedIcon(){
	if(connected_icon_state && !connected_to_server){
		IMImage icon(disconnected_icon);
		icon.setSize(vec2(100, 100));
		imGUI.getHeader().setElement(icon);
		connected_icon_state = false;
	}else if(!connected_icon_state && connected_to_server){
		IMImage icon(connected_icon);
		icon.setSize(vec2(100, 100));
		imGUI.getHeader().setElement(icon);
		connected_icon_state = true;
	}
}
float bandwith_timer = 0.0f;
void UpdateBandwidth(){
	if(connected_to_server){
		bandwith_timer += time_step;
		if(bandwith_timer >= 1.0f){
			imGUI.getHeader(1).clear();
			bandwith_timer = 0.0f;
			IMText upload_text("Upload " + upload_bandwidth + " bytes/second", client_connect_font);
			IMText download_text("Download " + download_bandwidth + " bytes/second", client_connect_font);
			IMDivider bandwith_divider(DOVertical);
			bandwith_divider.append(upload_text);
			bandwith_divider.append(download_text);

			IMImage background(white_background);
			background.setSize(vec2(300, 300));
			background.setZOrdering(0);
			background.setBorderColor(vec4(0,0,0,0.25));
			background.setBorderSize(1.0f);
			background.setColor(vec4(0,0,0,0.5));
			imGUI.getHeader(1).addFloatingElement(background, "background", vec2(0.0f));

			imGUI.getHeader(1).setElement(bandwith_divider);
			upload_bandwidth = 0;
			download_bandwidth = 0;
		}
	}
}

void HandleLevelChosen(string chosen_level_name, string chosen_level_path){
	if(chosen_level_path == level_path){
		//Already on the level that the user want to join.
		trying_to_connect = true;
	}else{
		if(FileExists(chosen_level_path)){
			DestroySocketTCP(main_socket);
			main_socket = SOCKET_ID_INVALID;
			DestroySocketTCP(retriever_socket);
			retriever_socket = SOCKET_ID_INVALID;

			//Not yet on the level that the user want to join.
			StorageSetInt32("ogmp_connect", 1);
			StorageSetString("ogmp_level_name", chosen_level_name);
			StorageSetString("ogmp_level_path", chosen_level_path);
			StorageSetString("ogmp_username", username);
			StorageSetString("ogmp_character", character);
			StorageSetString("ogmp_address", current_server.address);
			StorageSetInt32("ogmp_port", current_server.port);
			LoadLevel(chosen_level_path);
		}else{
			AddError("This map is not installed.");
		}
	}
}

void SeparateMessages(){
	if(data_collection.size() < 4){
		return;
	}
	array<uint8> size_array = {data_collection[0], data_collection[1], data_collection[2], data_collection[3]};
	uint message_size = GetIntFromByteArray(size_array);
	if( data_collection.size() < message_size + 4 ){
		return;
	}
	array<uint8> message;
	for(uint i = 4; i < message_size + 4; i++){
		message.insertLast(data_collection[i]);
	}
	data_collection.removeRange(0, message_size + 4);
	ProcessIncomingMessage(message);
}

int GetIntFromByteArray(array<uint8> b){
	int i = (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | (b[3]);
	return i;
}

void SetWindowDimensions(int w, int h)
{
	imGUI.doScreenResize();
}

void PreConnectedKeyChecks(){
    if(GetInputPressed(ReadCharacterID(player_id).controller_id, "p") && !trying_to_connect){
		if(cc_ui_added){
			RemoveUI();
			server_retriever.server_index = 0;
			server_retriever.online_servers.resize(0);
		}else{
			AddUI();
		}
    }
}

void KeyChecks(){
	int controller_id = ReadCharacterID(player_id).controller_id;

	if(chat.chat_input_shown){
		return;
	}

	if(GetInputPressed(controller_id, "k")) {
		if((permanent_health > 0) && (temp_health > 0)) {
			SendSavePosition();
		}
	}
	else if(GetInputPressed(controller_id, "l")) {
		if((permanent_health > 0) && (temp_health > 0)) {
			SendLoadPosition();
		}
	}else if(GetInputPressed(controller_id, "p")){
		if(cc_ui_added){
			server_retriever.ResetGetters();
			RemoveUI();
		}else{
			AddUI();
		}
  }
}

void ConnectToServer(){
    if(trying_to_connect){
        if( main_socket == SOCKET_ID_INVALID ) {
            if( level_name != "") {
				main_socket = CreateSocketTCP(current_server.address, current_server.port);
                if( main_socket != SOCKET_ID_INVALID ) {
                    Log( info, "Connected " + main_socket );
					trying_to_connect = false;
					SendSignOn();
                } else {
                    Log( warning, "Unable to connect" );
                }
            }
        }
		if( !IsValidSocketTCP(main_socket) ){
			Log(info, "Socket no longer valid");
			main_socket = SOCKET_ID_INVALID;
			connected_to_server = false;
			trying_to_connect = false;
		}
    }
}

void DisconnectFromServer(){
	DestroySocketTCP(main_socket);
	main_socket = SOCKET_ID_INVALID;
	DestroySocketTCP(retriever_socket);
	retriever_socket = SOCKET_ID_INVALID;
	connected_to_server = false;
	currentUIState = UsernameUI;
	chat.ClearChat();
	RemoveAllExceptPlayer();
}

void SendSavePosition(){
	array<uint8> message;
	message.insertLast(SavePosition);
	SendData(message);
}

void SendLoadPosition(){
	array<uint8> message;
	message.insertLast(LoadPosition);
	SendData(message);
}

void SendSignOn(){
	array<uint8> message;
	message.insertLast(SignOn);
	MovementObject@ player = ReadCharacterID(player_id);
	vec3 position = player.position;

	addToByteArray(username, @message);
	addToByteArray(character, @message);
	addToByteArray(level_name, @message);
	addToByteArray(level_path, @message);
	addToByteArray("1.0.0", @message);
	addToByteArray(position.x, @message);
	addToByteArray(position.y, @message);
	addToByteArray(position.z, @message);

	SendData(message);
}

void SendChatMessage(string chat_message){
	array<uint8> message;
	message.insertLast(Message);
	addToByteArray(username, @message);
	addToByteArray(chat_message, @message);
	SendData(message);
}

array<uint8> toByteArray(string message){
	array<uint8> data;
	for(uint i = 0; i < message.length(); i++){
		data.insertLast(message.substr(i, 1)[0]);
	}
	return data;
}

void addToByteArray(string message, array<uint8> @data){
	uint8 message_length = message.length();
	data.insertLast(message_length);
	for(uint i = 0; i < message_length; i++){
		data.insertLast(message.substr(i, 1)[0]);
	}
}

void addToByteArray(float value, array<uint8> @data){
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

void addToByteArray(uint8 value, array<uint8> @data){
	data.insertLast(value);
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

void SendPlayerUpdate(){
	array<uint8> message;
	message.insertLast(UpdateGame);

	player_variables.AddUpdateMessage(@message);
	SendData(message);
}

vec3 GetPlayerTargetVelocity() {
	if(chat.chat_input_shown){
		return vec3(0);
	}
    vec3 target_velocity(0.0f);
    vec3 right;
    {
        right = camera.GetFlatFacing();
        float side = right.x;
        right.x = -right .z;
        right.z = side;
    }
	int controller_id = ReadCharacterID(player_id).controller_id;

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

void UpdateTimeCriticalPlayerVariables(){
	if(chat.chat_input_shown){
		return;
	}
	MovementObject@ player = ReadCharacterID(player_id);
	int controller_id = player.controller_id;
	if(GetInputPressed(controller_id, "crouch")) {
		MPWantsToRoll = true;
	}
	if(GetInputPressed(controller_id, "jump")) {
	  MPWantsToJumpOffWall = true;
	}
	if(GetInputPressed(controller_id, "grab")) {
	  MPActiveBlock = true;
	}
}

class PlayerVariables{
	array<PlayerVariable@> variables;
	void AddVariable(PlayerVariable var){
		variables.insertLast(@var);
	}
	void AddUpdateMessage(array<uint8>@ message){
		for(uint i = 0; i < variables.size(); i++){
			variables[i].AddToUpdateMessage(@message);
		}
	}
	void ClearAll(){
		variables.resize(0);
	}
}

class PlayerVariable{
	uint8 variable_type;
	bool initial_update = true;
	PlayerVariable(){}
	void AddToUpdateMessage(array<uint8>@ message){}
	void GetValue(){}
}

class PlayerVariableInput : PlayerVariable{
	bool current_value;
	int controller_id;
	string key_name;
	PlayerVariableInput(int _controller_id, string _key_name, uint8 _variable_type){
		controller_id = _controller_id;
		key_name = _key_name;
		variable_type = _variable_type;
	}
	void AddToUpdateMessage(array<uint8>@ message){
		bool source_value = GetInputDown(controller_id, key_name);
		if(source_value != current_value || initial_update){
			initial_update = false;
			current_value = source_value;
			addToByteArray(variable_type, message);
			addToByteArray(current_value, message);
			/*Print("Variable " + key_name + " value " + current_value + "\n");*/
		}
	}
}

class PlayerVariableFloatVar : PlayerVariable{
	string var_name;
	float current_value;
	int player_id;
	MovementObject@ player;
	PlayerVariableFloatVar(int _player_id, string _var_name, uint8 _variable_type){
		player_id = _player_id;
		var_name = _var_name;
		//TODO this handle on the player character might not be the best solution, to be tested.
		@player = ReadCharacterID(player_id);
		variable_type = _variable_type;
	}
	void AddToUpdateMessage(array<uint8>@ message){
		float source_value = player.GetFloatVar(var_name);
		if(source_value != current_value || initial_update){
			initial_update = false;
			current_value = source_value;
			addToByteArray(variable_type, message);
			addToByteArray(current_value, message);
			/*Print("Variable " + var_name + " value " + current_value + "\n");*/
		}
	}
}

class PlayerVariableIntVar : PlayerVariable{
	string var_name;
	int current_value;
	int player_id;
	MovementObject@ player;
	PlayerVariableIntVar(int _player_id, string _var_name, uint8 _variable_type){
		player_id = _player_id;
		var_name = _var_name;
		//TODO this handle on the player character might not be the best solution, to be tested.
		@player = ReadCharacterID(player_id);
		variable_type = _variable_type;
	}
	void AddToUpdateMessage(array<uint8>@ message){
		int source_value = player.GetIntVar(var_name);
		if(source_value != current_value || initial_update){
			initial_update = false;
			current_value = source_value;
			addToByteArray(variable_type, message);
			addToByteArray(current_value, message);
			/*Print("Variable " + var_name + " value " + current_value + "\n");*/
		}
	}
}

class PlayerVariableBoolVar : PlayerVariable{
	string var_name;
	bool current_value;
	int player_id;
	MovementObject@ player;
	PlayerVariableBoolVar(int _player_id, string _var_name, uint8 _variable_type){
		player_id = _player_id;
		var_name = _var_name;
		//TODO this handle on the player character might not be the best solution, to be tested.
		@player = ReadCharacterID(player_id);
		variable_type = _variable_type;
	}
	void AddToUpdateMessage(array<uint8>@ message){
		bool source_value = player.GetBoolVar(var_name);
		if(source_value != current_value || initial_update){
			initial_update = false;
			current_value = source_value;
			addToByteArray(variable_type, message);
			addToByteArray(current_value, message);
			/*Print("Variable " + var_name + " value " + current_value + "\n");*/
		}
	}
}

class PlayerVariableDirection : PlayerVariable{
	float dir_x;
	float dir_z;
	MovementObject@ player;
	PlayerVariableDirection(int _player_id){
		//TODO this handle on the player character might not be the best solution, to be tested.
		@player = ReadCharacterID(player_id);
		vec3 player_dir = GetPlayerTargetVelocity();
	}
	void AddToUpdateMessage(array<uint8>@ message){
		vec3 player_dir = GetPlayerTargetVelocity();
		if(dir_x != player_dir.x || initial_update){
			dir_x = player_dir.x;
			addToByteArray(direction_x, message);
			addToByteArray(dir_x, message);
			/*Print("Variable dirx" + " value " + dir_x + "\n");*/
		}
		if(dir_z != player_dir.z || initial_update){
			dir_z = player_dir.z;
			addToByteArray(direction_z, message);
			addToByteArray(dir_z, message);
			/*Print("Variable dirz" + " value " + dir_z + "\n");*/
		}
		initial_update = false;
	}
}

class PlayerVariablePosition : PlayerVariable{
	float pos_x;
	float pos_y;
	float pos_z;
	MovementObject@ player;
	PlayerVariablePosition(int _player_id){
		//TODO this handle on the player character might not be the best solution, to be tested.
		@player = ReadCharacterID(player_id);
	}
	void AddToUpdateMessage(array<uint8>@ message){
		if(pos_x != player.position.x || initial_update){
			pos_x = player.position.x;
			addToByteArray(position_x, message);
			addToByteArray(pos_x, message);
			/*Print("Variable posx" + " value " + pos_x + "\n");*/
		}
		if(pos_y != player.position.y || initial_update){
			pos_y = player.position.y;
			addToByteArray(position_y, message);
			addToByteArray(pos_y, message);
			/*Print("Variable posy" + " value " + pos_y + "\n");*/
		}
		if(pos_z != player.position.z || initial_update){
			pos_z = player.position.z;
			addToByteArray(position_z, message);
			addToByteArray(pos_z, message);
			/*Print("Variable posz" + " value " + pos_z + "\n");*/
		}
		initial_update = false;
	}
}

class PlayerVariableVelocity : PlayerVariable{
	float vel_x;
	float vel_y;
	float vel_z;
	MovementObject@ player;
	PlayerVariableVelocity(int _player_id){
		//TODO this handle on the player character might not be the best solution, to be tested.
		@player = ReadCharacterID(player_id);
	}
	void AddToUpdateMessage(array<uint8>@ message){
		if(vel_x != player.velocity.x || initial_update){
			vel_x = player.velocity.x;
			addToByteArray(velocity_x, message);
			addToByteArray(vel_x, message);
			/*Print("Variable vel_x" + " value " + vel_x + "\n");*/
		}
		if(vel_y != player.velocity.y || initial_update){
			vel_y = player.velocity.y;
			addToByteArray(velocity_y, message);
			addToByteArray(vel_y, message);
			/*Print("Variable vel_y" + " value " + vel_y + "\n");*/
		}
		if(vel_z != player.velocity.z || initial_update){
			vel_z = player.velocity.z;
			addToByteArray(velocity_z, message);
			addToByteArray(vel_z, message);
			/*Print("Variable vel_z" + " value " + vel_z + "\n");*/
		}
		initial_update = false;
	}
}

enum PlayerVariableType{
	crouch = 0,
	jump = 1,
	attack = 2,
	grab = 3,
	item = 4,
	drop = 5,
	blood_damage = 6,
	blood_health = 7,
	block_health = 8,
	temp_health = 9,
	permanent_health = 10,
	blood_amount = 11,
	recovery_time = 12,
	roll_recovery_time = 13,
	knocked_out = 14,
	ragdoll_type = 15,
	blood_delay = 16,
	state = 17,
	cut_throat = 18,
	position_x = 19,
	position_y = 20,
	position_z = 21,
	direction_x = 22,
	direction_z = 23,
	remove_blood = 24,
	velocity_x = 25,
	velocity_y = 26,
	velocity_z = 27
}

//TODO Add roll jumpoffwall and activeblock

PlayerVariables player_variables;
void SetupPlayerVariables(){
	if(player_id == -1){
		return;
	}
	MovementObject@ player = ReadCharacterID(player_id);
	int controller_id = player.controller_id;
	player_variables.ClearAll();
	//All the input variables to keep track of.
	player_variables.AddVariable(PlayerVariableInput(controller_id, "crouch", crouch));
	player_variables.AddVariable(PlayerVariableInput(controller_id, "jump", jump));
	player_variables.AddVariable(PlayerVariableInput(controller_id, "attack", attack));
	player_variables.AddVariable(PlayerVariableInput(controller_id, "grab", grab));
	player_variables.AddVariable(PlayerVariableInput(controller_id, "item", item));
	player_variables.AddVariable(PlayerVariableInput(controller_id, "drop", drop));
	//All the float variables.
	player_variables.AddVariable(PlayerVariableFloatVar(player_id, "blood_damage", blood_damage));
	player_variables.AddVariable(PlayerVariableFloatVar(player_id, "blood_health", blood_health));
	player_variables.AddVariable(PlayerVariableFloatVar(player_id, "block_health", block_health));
	player_variables.AddVariable(PlayerVariableFloatVar(player_id, "temp_health", temp_health));
	player_variables.AddVariable(PlayerVariableFloatVar(player_id, "permanent_health", permanent_health));
	player_variables.AddVariable(PlayerVariableFloatVar(player_id, "blood_amount", blood_amount));
	player_variables.AddVariable(PlayerVariableFloatVar(player_id, "recovery_time", recovery_time));
	player_variables.AddVariable(PlayerVariableFloatVar(player_id, "roll_recovery_time", roll_recovery_time));

	//All the integer variables.
	player_variables.AddVariable(PlayerVariableIntVar(player_id, "knocked_out", knocked_out));
	player_variables.AddVariable(PlayerVariableIntVar(player_id, "ragdoll_type", ragdoll_type));
	player_variables.AddVariable(PlayerVariableIntVar(player_id, "blood_delay", blood_delay));
	player_variables.AddVariable(PlayerVariableIntVar(player_id, "state", state));
	//All the bool variables.
	player_variables.AddVariable(PlayerVariableBoolVar(player_id, "cut_throat", cut_throat));

	player_variables.AddVariable(PlayerVariablePosition(player_id));
	player_variables.AddVariable(PlayerVariableVelocity(player_id));
	player_variables.AddVariable(PlayerVariableDirection(player_id));
}

void UpdateInput(){
	chat.Update();
}

void SendData(array<uint8> message){
    if( IsValidSocketTCP(main_socket) ){
		/*Print("Sending data size " + message.size() + "\n");*/
		upload_bandwidth += message.size();
        SocketTCPSend(main_socket,message);
    }
	else{
		Log(info, "Socket no longer valid");
        main_socket = SOCKET_ID_INVALID;
		connected_to_server = false;
		trying_to_connect = false;
    }
}

void RemoveAllExceptPlayer() {
    int num = GetNumCharacters();
	array<int> remove_ids;
    for(int i=0; i<num; ++i){
        MovementObject@ char = ReadCharacter(i);
        if(char.GetID() != player_id){
            char.Execute("MPRemoveBillboard();");
            remove_ids.insertLast(char.GetID());
        }
    }
	for(uint i=0; i<remove_ids.size(); ++i){
		DeleteObjectID(remove_ids[i]);
	}
    remote_players.resize(0);
	MovementObject@ player = ReadCharacterID(player_id);
	player.Execute("situation.clear();");
}

int GetPlayerCharacterID() {
    int num = GetNumCharacters();
    for(int i=0; i<num; ++i){
        MovementObject@ char = ReadCharacter(i);
        if(char.controlled){
            return char.GetID();
        }
    }
    return -1;
}
bool HasFocus(){
	return false;
}

class Chat{
	IMDivider@ chat_divider;
	IMDivider@ chat_input_divider;
	IMDivider@ chat_query_divider;
	IMText@ chat_message_label;
	float chat_width = 1000.0f;
	float chat_height = 50.0f;
	int move_in_time = 250;
	int fade_out_time = 2500;
	string white_background = "Textures/ui/menus/main/white_square.png";
	array<ChatMessage@> chat_messages;
	uint num_chat_messages = 5;
	string new_chat_message = "";
	int current_index = 0;
	int cursor_offset = 0;
	bool chat_input_shown = false;
	vec4 own_message_color(0.0, 0.80, 0.50, 0.5);
	vec4 other_message_color(0.0, 0.50, 0.80, 0.5);
	vec4 server_message_color(1.0, 1.0, 1.0, 0.5);
	IMPulseAlpha pulse_cursor(1.0f, 0.0f, 2.0f);
	void Initialize(){
		IMDivider whole_chat("whole_chat", DOVertical);

		@chat_divider = IMDivider("chat_divider", DOVertical);
		@chat_input_divider = IMDivider("chat_input_divider", DOVertical);

		whole_chat.append(chat_divider);
		whole_chat.append(chat_input_divider);

		whole_chat.setAlignment(CACenter, CATop);
		/*chat_divider.setAlignment(CACenter, CATop);*/
		imGUI.getFooter().setAlignment(CACenter, CATop);

		//chat_divider.showBorder();
		imGUI.getFooter().setElement(whole_chat);
	}
	void ClearChat(){
		chat_divider.clear();
		chat_messages.resize(0);
		DrawChat();
	}
	void AddMessage(string message_, string source_, bool notif_){
		chat_divider.clear();
		vec4 background_color;
		if(source_ == username){
			background_color = own_message_color;
		}else if(source_ == "server"){
			background_color = server_message_color;
		}else{
			background_color = other_message_color;
		}
		chat_messages.insertLast(ChatMessage(message_, source_, notif_, background_color));
		DrawChat();
	}
	void DrawChat(){
		for(uint i = 0; i < chat_messages.size(); i++){
			DrawMessage(chat_messages[i], i);
		}
		if(chat_messages.size() > num_chat_messages){
			chat_messages.removeAt(0);
		}
	}
	void DrawMessage(ChatMessage@ chat_message, uint index){
		float left_offset = 25.0f;
		float background_size_offset = 10.0f;
		float source_width = 200.0f;
		float move_distance = 0;

		if(index == (chat_messages.size() - 1) ){
			move_distance = num_chat_messages * chat_height;
		}else if((chat_messages.size() - 1) == num_chat_messages){
			move_distance = chat_height;
		}

		IMDivider whole_divider("whole_divider", DOHorizontal);
		whole_divider.addUpdateBehavior(IMMoveIn ( move_in_time, vec2(0, move_distance), inSineTween ), "");

		IMDivider message_divider("message_divider", DOHorizontal);
		IMContainer message_container(chat_width, chat_height);
		/*message_container.showBorder();*/
		message_container.setAlignment(CALeft, CACenter);
		IMImage background(white_background);

		FontSetup username_font = main_font;
		username_font.color = chat_message.background_color;
		username_font.color.a = 1.0f;

		message_divider.appendSpacer(left_offset);
		message_divider.setZOrdering(2);
		background.setZOrdering(0);
		background.setBorderColor(vec4(0,0,0,0.25));
		background.setBorderSize(1.0f);
		background.setColor(chat_message.background_color);
		message_container.addFloatingElement(background, "background", vec2(0.0f));

		message_container.setElement(message_divider);
		if(chat_message.notif){
			IMText message_text(chat_message.message, main_font);
			message_divider.append(message_text);
			background.setSize(vec2(chat_width - background_size_offset, chat_height - background_size_offset));
		}else{
			IMDivider source_divider("source_divider", DOHorizontal);
			IMContainer source_container(source_width, chat_height);

			source_container.setAlignment(CALeft, CACenter);
			source_container.setElement(source_divider);
			background.setSize(vec2(chat_width - source_width - background_size_offset, chat_height - background_size_offset));
			message_container.setSizeX(chat_width - source_width);

			IMText label_source(chat_message.source, username_font);
			IMText label_text(chat_message.message, main_font);
			whole_divider.append(source_container);
			source_divider.append(label_source);
			message_divider.append(label_text);
		}
		whole_divider.append(message_container);
		chat_divider.append(whole_divider);
	}
	void AddChatInput(){
		MovementObject@ player = ReadCharacterID(player_id);
		player.velocity = vec3(0);
		player.Execute("SetState(_ground_state);");
		player.Execute("this_mo.SetAnimation(\"Data/Animations/r_actionidle.anm\", 20.0f);");

		@chat_query_divider = IMDivider("new_chat_divider", DOHorizontal);
		IMContainer new_chat_container(chat_width, chat_height);
		IMImage background(white_background);

		chat_query_divider.setZOrdering(2);
		background.setZOrdering(0);

		background.setSize(vec2(chat_width, chat_height));
		background.setColor(vec4(0,0,0,0.55));
		new_chat_container.addFloatingElement(background, "background", vec2(0));
		new_chat_container.addUpdateBehavior(IMMoveIn ( move_in_time, vec2(0, chat_height), inSineTween ), "");
		new_chat_container.setElement(chat_query_divider);

		FontSetup input_font = main_font;
		input_font.color = vec4(1);
		input_font.shadowed = true;
		@chat_message_label = IMText(new_chat_message, input_font);
		IMText cursor("_", input_font);
		chat_message_label.setZOrdering(2);
		cursor.setZOrdering(2);

		cursor.addUpdateBehavior(pulse_cursor, "");
		chat_query_divider.append(chat_message_label);
		chat_query_divider.append(cursor);
		chat_input_divider.append(new_chat_container);
		//Make sure the last pressed key is not registered by the chat on create. Wait for input.
		array<KeyboardPress> inputs = GetRawKeyboardInputs();
		if(inputs.size() < 1){
			initial_sequence_id = 0;
		}else{
			initial_sequence_id = inputs[inputs.size() -1].s_id;
		}
		chat_input_shown = true;
	}
	void SetCurrentChatMessage(){
		FontSetup input_font = main_font;
		input_font.color = vec4(1);
		input_font.shadowed = true;

		chat_query_divider.clear();
		@chat_message_label = IMText("", input_font);
		chat_query_divider.append(chat_message_label);
		IMText cursor("_", input_font);
		cursor.addUpdateBehavior(pulse_cursor, "");
		chat_message_label.setText(new_chat_message);
		chat_query_divider.append(cursor);
	}
	void RemoveChatInput(){
		if(chat_input_shown){
			MovementObject@ player = ReadCharacterID(player_id);
			player.Execute("SetState(_movement_state);");
			chat_input_divider.clear();
			new_chat_message = "";
			chat_input_shown = false;
		}
	}
	void Update(){
		if(!cc_ui_added){
			if(chat_input_shown){
				array<KeyboardPress> inputs = GetRawKeyboardInputs();
				if(inputs.size() > 0){
					uint16 possible_new_input = inputs[inputs.size()-1].s_id;
					if(possible_new_input != uint16(initial_sequence_id)){
						uint32 keycode = inputs[inputs.size()-1].keycode;
						initial_sequence_id = inputs[inputs.size()-1].s_id;
						uint max_query_length = 60;
						bool get_upper_case = false;

						/*Print("keycode " + keycode + "\n");*/

						if(GetInputDown(ReadCharacterID(player_id).controller_id, "shift")){
							get_upper_case =true;
						}

						array<int> ignore_keycodes = {27};
						if(ignore_keycodes.find(keycode) != -1 || keycode > 500){
							return;
						}

						//Backspace
						if(keycode == 8){
							//Check if there are enough chars to delete the last one.
							if(new_chat_message.length() - cursor_offset > 0){
								uint new_length = new_chat_message.length() - 1;
								if(new_length >= 0 && new_length <= max_query_length){
									new_chat_message.erase(new_chat_message.length() - cursor_offset - 1, 1);
									SetCurrentChatMessage();
									return;
								}
							}else{
								return;
							}
						}
						//Delete pressed
						else if(keycode == 127){
							if(cursor_offset > 0){
								new_chat_message.erase(new_chat_message.length() - cursor_offset, 1);
								cursor_offset--;
								SetCurrentChatMessage();
							}
							return;
						}
						//Enter/return pressed
						else if(keycode == 13){
							if(new_chat_message != ""){
								SendChatMessage(new_chat_message);
							}
							current_index = 0;
							cursor_offset = 0;
							RemoveChatInput();
							return;
						}

						if(get_upper_case){
							keycode = ToUpperCase(keycode);
						}
						string new_character('0');
						new_character[0] = keycode;
						new_chat_message.insert(new_chat_message.length() - cursor_offset, new_character);
						SetCurrentChatMessage();
					}
				}
			}else{
				if(GetInputPressed(0, "return")){
					AddChatInput();
				}
			}
		}
	}
}
class ChatMessage{
	string source;
	string message;
	bool notif;
	vec4 background_color;
	ChatMessage(string message_, string source_, bool notif_, vec4 background_color_){
		message = message_;
		source = source_;
		notif = notif_;
		background_color = background_color_;
	}
}
