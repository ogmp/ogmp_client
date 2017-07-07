FontSetup main_font("arial", 30 , vec4(0,0,0,0.75), false);
FontSetup error_font("arial", 40 , vec4(0.85,0,0,0.75), true);
FontSetup client_connect_font("arial", 30 , vec4(1,1,1,0.75), true);
FontSetup client_connect_font_small("arial", 20 , vec4(1,1,1,0.75), true);
IMMouseOverPulseColor mouseover_fontcolor(vec4(1), vec4(1), 5.0f);
IMPulseAlpha pulse(1.0f, 0.0f, 2.0f);
string connected_icon = "Images/connected.png";
string disconnected_icon = "Images/disconnected.png";
string white_background = "Textures/ui/menus/main/white_square.png";
string brushstroke_background = "Textures/ui/menus/main/brushStroke.png";

string turner = "Data/Characters/ogmp/turner.xml";

array<string> adjectives = {"Little", "Old", "Bad", "Brave", "Handsome", "Quaint", "Prickly", "Nervous", "Jolly", "Gigantic", "Itchy", "Thoughtless", "Crooked", "Hissing", "Slow", "Flaky", "Damaged"};
array<string> nouns = {"Cat", "Walnut", "Bird", "Cookie", "Aardvark", "Boy", "Dame", "Kitty", "Person", "Cow", "Dragon", "Investor", "Cook", "Frenchman", "Priest", "Tiger", "Zebra", "Raven", "David"};
array<string> character_names = {"Turner", "Guard", "Raider Rabbit", "Pale Turner", "Cat", "Female Rabbit", "Rat", "Female Rat", "Hooded Rat", "Light Armored Dog Big", "Rabbot", "Wolf"};
array<string> character_options = {"turner", "guard", "raider_rabbit", "pale_turner", "cat", "female_rabbit_1", "rat", "female_rat", "hooded_rat", "lt_dog_big", "rabbot", "wolf"};

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
uint8 ServerInfo = 11;
uint8 LevelList = 12;
uint8 PlayerList = 13;

uint retriever_socket = SOCKET_ID_INVALID;
uint main_socket = SOCKET_ID_INVALID;

ServerRetriever server_retriever;

array<ServerConnectionInfo@> server_list = {	ServerConnectionInfo("127.0.0.1", 2000),
												ServerConnectionInfo("127.0.0.1", 80),
												ServerConnectionInfo("127.0.0.1", 1337),
												ServerConnectionInfo("52.56.230.41", 2000)};

class ServerConnectionInfo{
	string server_name;
	int nr_players;
	string address;
	int port;
	bool valid = false;
	double latency;
	array<LevelInfo@> levels;
	array<PlayerInfo@> players;
	ServerConnectionInfo(string address_, int port_){
		address = address_;
		port = port_;
	}
}

class Dropdown{
	vec2 button_size(500, 60);
	float button_size_offset = 10.0f;
	array<string> options;
	array<string> option_names;
	string current_value;
	IMContainer@ parent;
	int index = 0;
	Dropdown(array<string> options_, array<string> option_names_, string current_value_, IMContainer@ parent_){
		@parent = parent_;
		options = options_;
		option_names = option_names_;
		current_value = current_value_;
		index = options.find(current_value);
		AddDropdown();
	}
	void AddDropdown(){
		parent.setSize(button_size);
		IMText first_option(option_names[index], client_connect_font);
		first_option.setZOrdering(2);
		parent.setElement(first_option);
		parent.addLeftMouseClickBehavior(IMFixedMessageOnClick("activate_dropdown"), "");
		IMImage background(white_background);
		background.setZOrdering(0);
		background.setSize(button_size - button_size_offset);
		background.setColor(vec4(0,0,0,0.75));
		parent.addFloatingElement(background, "background", vec2(button_size_offset / 2.0f));
	}
	void SetNewValue(string value_){
		current_value = value_;
		index = options.find(current_value);
	}
	void Deactivate(){
		parent.clearLeftMouseClickBehaviors();
		parent.clear();
		AddDropdown();
	}
	void Activate(){
		parent.clearLeftMouseClickBehaviors();
		parent.clear();
		
		IMContainer options_holder(button_size.x, button_size.y);
		IMDivider options_divider("options_divider", DOVertical);
		options_holder.addFloatingElement(options_divider, "options_divider", vec2(button_size_offset / 2.0f));
		
		IMImage main_background(white_background);
		main_background.setClip(false);
		main_background.setZOrdering(4);
		main_background.setSize(vec2(button_size.x, button_size.y * options.size()));
		main_background.setColor(vec4(0,0,0,0.75));
		options_holder.addFloatingElement(main_background, "option_background", vec2(button_size_offset / 2.0f));
		
		for(uint i = 0; i < options.size(); i++){
			IMContainer option_holder(button_size.x, button_size.y);
			option_holder.sendMouseOverToChildren(true);
			IMText option_label(option_names[i], client_connect_font);
			option_label.addMouseOverBehavior(mouseover_fontcolor, "");
			option_holder.addLeftMouseClickBehavior(IMFixedMessageOnClick("option_chosen", options[i]), "");
			option_label.setZOrdering(6);
			option_holder.setElement(option_label);
			
			IMImage background(white_background);
			background.setZOrdering(4);
			background.setSize(button_size - button_size_offset);
			background.setColor(vec4(0,0,0,0.75));
			option_holder.addFloatingElement(background, "option_background", vec2(button_size_offset / 2.0f));
			options_divider.append(option_holder);
		}
		
		parent.setElement(options_holder);
	}
}

class LevelInfo{
	string level_name;
	string level_path;
	int nr_players;
	LevelInfo(string level_name_, string level_path_, int nr_players_){
		level_name = level_name_;
		level_path = level_path_;
		nr_players = nr_players_;
	}
}

class PlayerInfo{
	string player_username;
	string player_character;
	PlayerInfo(string player_username_, string player_character_){
		player_username = player_username_;
		player_character = player_character_;
	}
}

class ServerRetriever{
	bool checking_servers = false;
	int max_connect_tries = 5;
	int connect_tries = 0;
	float connect_try_interval = 0.1f;
	float timer = 0.0f;
	int server_index = 0;
	uint64 start_time;
	array<ServerConnectionInfo@> online_servers;
	bool getting_server_info = false;
	bool getting_player_list = false;
	bool getting_level_list = false;
	bool checked_online_servers = false;
	bool got_level_list = false;
	bool got_player_list = false;
	void Update(){
		if(getting_server_info){
			UpdateGetServerInfo();
		}
		else if(getting_level_list){
			UpdateGetLevelList();
		}
		else if(getting_player_list){
			UpdateGetPlayerList();
		}
		else if(checking_servers){
			UpdateCheckingServers();
		}
	}
	void ResetGetters(){
        Log( info, "ResetGetters");
		checked_online_servers = false;
		got_level_list = false;
		got_player_list = false;
		online_servers.resize(0);
	}
	void UpdateGetLevelList(){
		timer += time_step;
		//Every interval check for a connection
		if(timer > connect_try_interval){
			timer = 0.0f;
			if( retriever_socket == SOCKET_ID_INVALID ) {
				retriever_socket = CreateSocketTCP(current_server.address, current_server.port);
				if( retriever_socket != SOCKET_ID_INVALID ) {
					Log( info, "socked valid");
				} else {
					Log( warning, "Unable to connect");
				}
			}
			if( IsValidSocketTCP(retriever_socket) ){
				Log(info, "Send LevelList");
				array<uint8> levellist_message = {LevelList};
				SocketTCPSend(retriever_socket, levellist_message);
				getting_level_list = false;
			}else{
				Log(info, "invalid");
				retriever_socket = SOCKET_ID_INVALID;
				connect_tries++;
				if(connect_tries == max_connect_tries){
					connect_tries = 0;
					getting_level_list = false;
				}
			}
		}
	}
	void UpdateGetServerInfo(){
		
	}
	void UpdateGetPlayerList(){
		timer += time_step;
		//Every interval check for a connection
		if(timer > connect_try_interval){
			timer = 0.0f;
			if( main_socket == SOCKET_ID_INVALID ) {
				Log( warning, "Socket is closed, can't get player list!");
			}
			if( IsValidSocketTCP(main_socket) ){
				Log(info, "Send PlayerList");
				array<uint8> playerlist_message = {PlayerList};
				SocketTCPSend(main_socket, playerlist_message);
				getting_player_list = false;
			}
		}
	}
	void UpdateCheckingServers(){
		if(server_index >= int(server_list.size())){
			return;
		}
		timer += time_step;
		//Every interval check for a connection
		if(timer > connect_try_interval){
			timer = 0.0f;
			if( retriever_socket == SOCKET_ID_INVALID ) {
				start_time = GetPerformanceCounter();
				retriever_socket = CreateSocketTCP(server_list[server_index].address, server_list[server_index].port);
				if( retriever_socket != SOCKET_ID_INVALID ) {
                    Log( info, "Connected " + retriever_socket );
					server_list[server_index].latency = (GetPerformanceCounter() - start_time) * 1000.0 / GetPerformanceFrequency();					
					online_servers.insertLast(server_list[server_index]);
				} else {
					Log( warning, "Unable to connect");
				}
			}
			if( !IsValidSocketTCP(retriever_socket) ){
				retriever_socket = SOCKET_ID_INVALID;
				connect_tries++;
				if(connect_tries == max_connect_tries){
					connect_tries = 0;
					GetNextServer();
				}
			}else{
				array<uint8> info_message = {ServerInfo};
				SocketTCPSend(retriever_socket,info_message);
				connect_tries = 0;
				GetNextServer();
				getting_server_info = true;
			}
		}
	}
	void SetServerInfo(string server_name_, int nr_players_){
        Log(info, "SetServerInfo " + server_name_);
		online_servers[online_servers.size() - 1].server_name = server_name_;
		online_servers[online_servers.size() - 1].nr_players = nr_players_;
		getting_server_info = false;
		retriever_socket = SOCKET_ID_INVALID;
		RefreshUI();
	}
	void SetLevelList(array<LevelInfo@> levels_){
		current_server.levels = levels_;
		getting_level_list = false;
		got_level_list = true;
		RefreshUI();
	}
	void SetPlayerList(array<PlayerInfo@> players_){
		current_server.players = players_;
		got_player_list = true;
		RefreshUI();
	}
	void GetNextServer(){
		server_index++;
		if(server_index >= int(server_list.size())){
			//Every server address has been checked.
			checked_online_servers = true;
			checking_servers = false;
			server_index = 0;
			RefreshUI();
		}
	}
	void CheckOnlineServers(){
		if(!checking_servers && !checked_online_servers){
			checking_servers = true;
		}
	}
	void GetLevelList(){
		if(!getting_level_list && !got_level_list){
			getting_level_list = true;
		}
	}
	void GetPlayerList(){
		if(!getting_player_list && !got_player_list){
			getting_player_list = true;
		}
	}
}

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
class Inputfield {
	bool active = false;
	bool pressed_return = false;
	int initial_sequence_id;
	IMText@ input_field;
	IMDivider@ parent;
	string query = "";
	string backup_query;
	int current_index = 0;
	int cursor_offset = 0;
	float long_press_input_timer = 0.0f;
	float long_press_timer = 0.0f;
	float long_press_threshold = 0.5f;
	float long_press_interval = 0.1f;
	uint max_query_length = 20;
	Inputfield(){
		
	}
	void Activate(){
		if(active){return;}
		
		//Freeze the player so it doesn't walk around.
		MovementObject@ player = ReadCharacterID(player_id);
		player.velocity = vec3(0);
		player.Execute("SetState(_ground_state);");
		
		backup_query = input_field.getText();
		query = "";
		active = true;
		pressed_return = false;
		array<KeyboardPress> inputs = GetRawKeyboardInputs();
		if(inputs.size() > 0){
			initial_sequence_id = inputs[inputs.size()-1].s_id;
		}else{
			initial_sequence_id = -1;
		}
		parent.clear();
		/*parent.clearLeftMouseClickBehaviors();*/
		IMText new_input_field("", client_connect_font);
		parent.append(new_input_field);
		@input_field = @new_input_field;
		IMText cursor("_", client_connect_font);
		cursor.addUpdateBehavior(pulse, "");
		cursor.setZOrdering(4);
		parent.append(cursor);
	}
	void Deactivate(){
		active = false;
		parent.clear();
		if(query == ""){
			query = backup_query;
		}
		IMText new_input_field(query, client_connect_font);
		parent.append(new_input_field);
		@input_field = @new_input_field;
	}
	void SetInputField(IMText@ _input_field, IMDivider@ _parent){
		@input_field = @_input_field;
		@parent = @_parent;
	}
	void Update(){
		if(active){
			if(GetInputPressed(0, "left")){
				if((cursor_offset) < int(query.length())){
					cursor_offset++;
					SetCurrentSearchQuery();
				}
			}
			else if(GetInputPressed(0, "right")){
				if(cursor_offset > 0){
					cursor_offset--;
					SetCurrentSearchQuery();
				}
			}
			if(long_press_timer > long_press_threshold){
				if(GetInputDown(0, "backspace")){
					long_press_input_timer += time_step;
					if(long_press_input_timer > long_press_interval){
						long_press_input_timer = 0.0f;
						//Check if there are enough chars to delete the last one.
						if(query.length() - cursor_offset > 0){
							uint new_length = query.length() - 1;
							if(new_length >= 0 && new_length <= max_query_length){
								query.erase(query.length() - cursor_offset - 1, 1);
								SetCurrentSearchQuery();
								return;
							}
						}else{
							return;
						}
					}
				}else if(GetInputDown(0, "delete")){
					long_press_input_timer += time_step;
					if(long_press_input_timer > long_press_interval){
						long_press_input_timer = 0.0f;
						//Check if there are enough chars to delete the next one.
						if(cursor_offset > 0){
							query.erase(query.length() - cursor_offset, 1);
							cursor_offset--;
							SetCurrentSearchQuery();
						}
						return;
					}
				}else if(GetInputDown(0, "left")){
					long_press_input_timer += time_step;
					if(long_press_input_timer > long_press_interval){
						long_press_input_timer = 0.0f;
						if((cursor_offset) < int(query.length())){
							cursor_offset++;
							SetCurrentSearchQuery();
						}
					}
					return;
				}else if(GetInputDown(0, "right")){
					long_press_input_timer += time_step;
					if(long_press_input_timer > long_press_interval){
						long_press_input_timer = 0.0f;
						if(cursor_offset > 0){
							cursor_offset--;
							imGUI.receiveMessage( IMMessage("refresh_menu_by_id") );
						}
					}
					return;
				}else{
					long_press_input_timer = 0.0f;
				}
				if(!GetInputDown(0, "delete") && !GetInputDown(0, "backspace") && !GetInputDown(0, "left") && !GetInputDown(0, "right")){
					long_press_timer = 0.0f;
				}
			}else{
				if(GetInputDown(0, "delete") || GetInputDown(0, "backspace") || GetInputDown(0, "left") || GetInputDown(0, "right")){
					long_press_timer += time_step;
				}else{
					long_press_timer = 0.0f;
				}
			}
			
			array<KeyboardPress> inputs = GetRawKeyboardInputs();
			if(inputs.size() > 0){
				uint16 possible_new_input = inputs[inputs.size()-1].s_id;
				if(possible_new_input != uint16(initial_sequence_id)){
					uint32 keycode = inputs[inputs.size()-1].keycode;
					initial_sequence_id = inputs[inputs.size()-1].s_id;
					//Print("new input = "+ keycode + "\n");
					bool get_upper_case = false;
					
					if(GetInputDown(ReadCharacterID(player_id).controller_id, "shift")){
						get_upper_case =true;
					}
					
					array<int> ignore_keycodes = {27};
					if(ignore_keycodes.find(keycode) != -1 || keycode > 500){
						return;
					}
					//Enter/return pressed
					if(keycode == 13){
						current_index = 0;
						cursor_offset = 0;
						active = false;
						pressed_return = true;
						username = query;
						//Put the player state back so it can walk again.
						MovementObject@ player = ReadCharacterID(player_id);
						player.velocity = vec3(0);
						player.Execute("SetState(_movement_state);");
						Deactivate();
						return;
					}
					//Backspace
					else if(keycode == 8){
						//Check if there are enough chars to delete the last one.
						if(query.length() - cursor_offset > 0){
							uint new_length = query.length() - 1;
							if(new_length >= 0 && new_length <= max_query_length){
								query.erase(query.length() - cursor_offset - 1, 1);
								active = true;
								SetCurrentSearchQuery();
								return;
							}
						}else{
							return;
						}
					}
					//Delete pressed
					else if(keycode == 127){
						if(cursor_offset > 0){
							query.erase(query.length() - cursor_offset, 1);
							cursor_offset--;
							active = true;
						}
						SetCurrentSearchQuery();
						return;
					}
					if(query.length() == 20){
						return;
					}
					if(get_upper_case){
						keycode = ToUpperCase(keycode);
					}
					string new_character('0');
					new_character[0] = keycode;
					query.insert(query.length() - cursor_offset, new_character);
					SetCurrentSearchQuery();
				}
			}
		}
	}
	void SetCurrentSearchQuery(){
		if(active && !pressed_return){
			parent.clear();
			@input_field = IMText("", client_connect_font);
			parent.append(input_field);
			IMText cursor("_", client_connect_font);
			cursor.addUpdateBehavior(pulse, "");
			if(cursor_offset > 0){
				string first_part = query.substr(0, query.length() - cursor_offset);
				input_field.setText(first_part);
				parent.append(cursor);
				string second_part = query.substr(query.length() - cursor_offset, query.length());
				IMText second_input_field(second_part, client_connect_font);
				parent.append(second_input_field);
			}else{
				input_field.setText(query);
				parent.append(cursor);
			}
		}
	}
	void ShowSearchResults(){
		
	}
	void GetSearchResults(string query){
		
	}
}
uint32 ToUpperCase(uint32 input){
	uint32 return_value = input;
	//Check if keycode is between a and z
	if(input >= 97 || input <= 122){
		return_value -= 32;
	}
	return return_value;
}
