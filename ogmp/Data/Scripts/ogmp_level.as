const int _movement_state = 0; // character is moving on the ground
const int _ground_state = 1; // character has fallen down or is raising up, ATM ragdolls handle most of this
const int _attack_state = 2; // character is performing an attack
const int _hit_reaction_state = 3; // character was hit or dealt damage to and has to react to it in some manner
const int _ragdoll_state = 4; // character is falling in ragdoll mode

bool debug = false;
bool has_client_connect_gui = false;
bool has_chat_gui = false;
bool showing_playerlist;
string client_uid;
string welcome_message;
string username;
string level_name;
string server_address;
string server_port;
bool connected_to_server = false;
float frequency = 1.0f;
float delay = 1.0f;
uint32 client_connect_id;
uint32 chat_id;
uint32 playerlist_id;
bool showing_chat_input = false;
array<MovementObject@> remote_players;

void UpdateOGMP() {
	CheckKeys();
	HandleConnection();
	HandleChat();
	DrawUsernames();
	SendUpdate();
}

void CheckKeys() {
	if(!has_gui && !has_client_connect_gui && GetInputPressed(controller_id, "f12") && GetPlayerCharacterID() != -1) {
		// If the user already has a client connect window we have to destroy it first.
		if(client_connect_id > 0) {
			gui.RemoveGUI(client_connect_id);
		}

		// This closes the current connection, so this has to be handled.
		if(connected_to_server) {
			Disconnect();
		}

		// Now we can create the html document. This is the object that will actually connect to the server.
		client_connect_id = gui.AddGUI("gamemenu", "ClientConnect\\clientconnect.html", int(GetScreenWidth()/1.5f), 500, 0);
		gui.Execute(client_connect_id, "GetPublicServers();");
		has_client_connect_gui = true;
		gui.Execute(client_connect_id,"level = \""+level_name+"\";");

		// Send current player position to client connect document for spawn.
		int player_id = GetPlayerCharacterID();

		if(player_id == -1) {
			return;
		}

		MovementObject@ char = ReadCharacter(player_id);
		gui.Execute(client_connect_id,"posx = "+char.position.x+";");
		gui.Execute(client_connect_id,"posy = "+char.position.y+";");
		gui.Execute(client_connect_id,"posz = "+char.position.z+";");
	}

	if(connected_to_server) {
		if(GetInputPressed(controller_id, "return")) {
			has_chat_gui = !has_chat_gui;
			gui.Execute(chat_id,"toggleChat();");
		}

		if(GetInputDown(controller_id, "f10")) {
			if(!showing_playerlist) {
				playerlist_id = gui.AddGUI("gamemenu","ClientConnect\\playerlist.html",GetScreenWidth()/2,GetScreenHeight()/2,0);
				gui.Execute(playerlist_id,"server_address = \""+server_address+"\"");
				gui.Execute(playerlist_id,"server_port = \""+server_port+"\"");

				showing_playerlist = true;
			}
		}

		if(showing_playerlist && !GetInputDown(controller_id, "f10")) {
			gui.RemoveGUI(playerlist_id);
			showing_playerlist = false;
		}

		if(GetInputPressed(controller_id, "k")) {
			MovementObject@ char = ReadCharacter(0);

			if((char.GetFloatVar("permanent_health") > 0) && (char.GetFloatVar("temp_health") > 0)) {
				string message = "type=SavePosition" + "&uid=" + client_uid;
				PrintDebug(message + "\n");
				gui.Execute(client_connect_id,"sendUpdate(\""+message+"\")");
			}
		}

		if(GetInputPressed(controller_id, "l")) {
			MovementObject@ char = ReadCharacter(0);

			if((char.GetFloatVar("permanent_health") > 0) && (char.GetFloatVar("temp_health") > 0)) {
				string message = "type=LoadPosition" + "&uid=" + client_uid;
				PrintDebug(message + "\n");
				gui.Execute(client_connect_id,"sendUpdate(\""+message+"\")");
			}
		}
	}
}

void HandleConnection() {
	if(has_client_connect_gui || connected_to_server) {
		string callback = gui.GetCallback(client_connect_id);

		//PrintDebug("Still here " + callback + "\n");
		while(callback != "") {
			//PrintDebug("client_connect callback: " + callback + "\n");

			//If there is a callback the gui should be closed.
			if(has_client_connect_gui) {
				PrintDebug("Disabling has client connect gui\n");
				has_client_connect_gui = false;
			}

			if(callback == "closeWindow") {
				callback = gui.GetCallback(client_connect_id);
				continue;
			}

			string type_check = callback.substr(0, 4);
			if(type_check == "type") {
				int update_counter = 1;
				array<array<array<string>>> first_level;
				//Every command is separated by a #
				array<string> separated_command_types = callback.split("#");

				int separated_commands_size = separated_command_types.size();
				for(int i=0; i<separated_commands_size; i++) {
					array<array<string>> second_level;
					//Every name and value combination is separated by a &
					//PrintDebug("Command: " + separated_command_types[i] + "\n");
					array<string> name_plus_var = separated_command_types[i].split("&");
					int name_plus_var_size = name_plus_var.size();
					for(int u=0; u<name_plus_var_size; u++) {
						//And then every name and value is separated by a =
						//PrintDebug("Name&Value " +name_plus_var[u]+"\n" );
						array<string> name_var = name_plus_var[u].split("=");
						int var_size = name_var.size();
						for(int y=0; y<var_size; y++) {
							//PrintDebug("Var: " + name_var[y] + "\n");
						}
						second_level.insertLast(name_var);
					}
					first_level.insertLast(second_level);

				}

				int first_level_size = first_level.size();
				for (int a = 0; a < first_level_size; a++) {
					if(first_level[a][0][1] == "SignOn") {
						string team;
						string character_dir;

						int second_level_size = first_level[a].size();
						for (int b = 0; b < second_level_size; b++) {
							if(first_level[a][b][0] == "uid") {
								client_uid = first_level[a][b][1];
							} else if(first_level[a][b][0] == "refr") {
								frequency = parseFloat(first_level[a][b][1]);
							} else if(first_level[a][b][0] == "welcome_message") {
								welcome_message = first_level[a][b][1];
							} else if(first_level[a][b][0] == "username") {
								username = first_level[a][b][1];
							} else if(first_level[a][b][0] == "team") {
								team = first_level[a][b][1];
							} else if(first_level[a][b][0] == "character") {
								character_dir = first_level[a][b][1];
							} else if(first_level[a][b][0] == "server") {
								server_address = first_level[a][b][1];
							} else if(first_level[a][b][0] == "port") {
								server_port = first_level[a][b][1];
							}
						}

						connected_to_server = true;

						int player_id = GetPlayerCharacterID();

						if(player_id == -1) {
							continue;
						}

						MovementObject@ char = ReadCharacter(player_id);
						char.Execute("MPIsConnected = true;");

						// Chat
						gui.Execute(client_connect_id,"connectSuccessful()");
						PrintDebug("Successfully connected to server. UID: " + client_uid + "\n");

						if(chat_id <= 0) {
							chat_id = gui.AddGUI("gamemenu","ClientConnect\\chat.html",400,400,0);

							gui.MoveTo(chat_id,0,GetScreenHeight()-400);
						}

						gui.Execute(chat_id,"addChat('System', 'Successfully connected to server.',true)");

						string filtered = join( welcome_message.split( "\"" ), "" );
						gui.Execute(chat_id,"addChat('System','Server message: "+filtered+"',true)");

						gui.Execute(chat_id,"name = '"+username+"';");

						for(int i=0; i<GetNumCharacters(); ++i) {
							PrintDebug("Adding player " + i + ": " + username + "\n");

							MovementObject@ other_char = ReadCharacter(i);
							//Every known character needs to be removed or else the situationawareness script will check the nonexisting movementobjects
							other_char.Execute("situation.clear();");
							if(other_char.controlled) {
								PrintDebug("Player is controlled\n");

								Object@ char_obj = ReadObjectFromID(char.GetID());
								ScriptParams@ params = char_obj.GetScriptParams();

								if(params.HasParam("Name")) {
									params.SetString("Name", username);
								} else{
									params.AddString("Name", username);
								}
								if(params.HasParam("Teams")) {
									params.SetString("Teams", team);
								} else{
									params.AddString("Teams", team);
								}
								other_char.Execute("SwitchCharacter(\"Data/Characters/" + character_dir + ".xml\");");
							} else{
								DeleteObjectID(other_char.GetID());
								i--;
							}
						}
					} else if(first_level[a][0][1] == "Timeout") {
						PrintDebug("Timeout\n");
						Disconnect();
					} else if(first_level[a][0][1] == "SpawnCharacter") {
						int second_level_size = first_level[a].size();
						array<string> new_player;
						string new_player_username;
						string new_player_char_dir;
						string new_player_team;
						float new_player_posx;
						float new_player_posy;
						float new_player_posz;

						//First all the variables need to be extracted from the incomming message.
						for (int b = 0; b < second_level_size; b++) {
							string name = first_level[a][b][0];
							string value = first_level[a][b][1];

							if(name == "username") {
								new_player_username = value;
							} else if(name == "character") {
								new_player_char_dir = "Data/Characters/ogmp/" + value + ".xml";
							} else if(name == "team") {
								new_player_team = value;
							} else if(name == "posx") {
								new_player_posx = parseFloat(value);
							} else if(name == "posy") {
								new_player_posy = parseFloat(value);
							} else if(name == "posz") {
								new_player_posz = parseFloat(value);
							}
						}

						//Then the new player is spawned
						int new_player_id = CreateObject(new_player_char_dir, false);

						//The newly created character is always the last item in the GetNumCharacters list.
						MovementObject@ new_char = ReadCharacter(GetNumCharacters()-1);
						new_char.Execute("MPIsConnected = true;");

						//Set spawn position.
						new_char.position.x = new_player_posx;
						new_char.position.y = new_player_posy;
						new_char.position.z = new_player_posz;

						//Just in case stop any movement.
						new_char.velocity = vec3(0);

						//Reset animations to avoid long arms.
						new_char.Execute("ResetSecondaryAnimation();");

						//This new character is added to our own remote_player list so we can keep track of it.
						remote_players.insertLast(new_char);

						//The paramters are attached to the Object for some reason and not the MovementObject.
						Object@ char_obj = ReadObjectFromID(new_char.GetID());
						ScriptParams@ params = char_obj.GetScriptParams();

						//A new Name parameter is added. This way we can later delete and update the right MovementObject by name.
						params.AddString("Name", new_player_username);

						if(params.HasParam("Teams")) {
							params.SetString("Teams", new_player_team);
						} else{
							params.AddString("Teams", new_player_team);
						}

						PrintDebug("Adding character with name: " + new_player_username + " and char dir : " + new_player_char_dir + " and team " + new_player_team + "\n");
					} else if(first_level[a][0][1] == "RemoveCharacter") {
						int second_level_size = first_level[a].size();
						string remove_name;
						int remove_id = -1;
						//First we need to get the username from the incommig command.
						for (int b = 0; b < second_level_size; b++) {
							PrintDebug("Command # " + a + " name: " + first_level[a][b][0] + " value: " + first_level[a][b][1] + "\n");
							string name = first_level[a][b][0];
							string value = first_level[a][b][1];

							if(name == "username") {
								remove_name = value;
							}
						}
						//Next we loop through the remote_players list to find the character with the correct name.
						int num_chars = remote_players.size();
						for(int i = 0; i< num_chars; i++) {
							MovementObject@ temp_char = remote_players[i];
							Object@ char_obj = ReadObjectFromID(temp_char.GetID());
							ScriptParams@ params = char_obj.GetScriptParams();
							if(params.HasParam("Name")) {
								string name_str = params.GetString("Name");
								if(remove_name == name_str) {
									//If the character with the right name is found the object is deleted and we remove the MovementObject from the remote_players list.
									remove_id = temp_char.GetID(); // TODO: check this out
									remote_players.removeAt(i);

									// There can only be one, stop. Could crash otherwise.
									break;
								}
							}
						}
						//If the character is not found the script will just skip it.
						if(remove_id != -1) {
							PrintDebug("remove player id: " + remove_id + " with name " + remove_name + "\n");
							DeleteObjectID(remove_id);
						}
						//Every character needs the situation updated or else they will check for the character we just removed.
						num_chars = GetNumCharacters();
						for(int i=0; i<num_chars; ++i) {
							MovementObject@ temp_char = ReadCharacter(i);
							temp_char.Execute("situation.clear();");
						}
					} else if(first_level[a][0][1] == "Update") {
						int second_level_size = first_level[a].size();

						string remote_player_name;
						int remote_player_id = -1;
						float remote_player_posx;
						float remote_player_posy;
						float remote_player_posz;
						float remote_player_dirx;
						float remote_player_dirz;
						float remote_player_blood_damage;
						float remote_player_blood_health;
						float remote_player_block_health;
						float remote_player_temp_health;
						float remote_player_permanent_health;
						bool remote_player_jump;
						bool remote_player_crouch;
						bool remote_player_attack;
						bool remote_player_grab;
						bool remote_player_item;
						bool remote_player_drop;
						bool remote_player_roll;
						bool remote_player_jumpoffwall;
						bool remote_player_activeblock;
						int remote_player_knocked_out;
						int remote_player_lives;
						float remote_player_blood_amount;
						float remote_player_recovery_time;
						float remote_player_roll_recovery_time;
						int remote_player_ragdoll_type;
						bool remote_player_remove_blood;
						bool remote_player_cut_throat;
						int remote_player_state;

						for (int b = 0; b < second_level_size; b++) {
							string name = first_level[a][b][0];
							string value = first_level[a][b][1];

							//PrintDebug("Name: " + name + " Value: " + value + "\n");

							if(name == "username") {
								remote_player_name = value;
							} else if(name == "posx") {
								remote_player_posx = parseFloat(value);
							} else if(name == "posy") {
								remote_player_posy = parseFloat(value);
							} else if(name == "posz") {
								remote_player_posz = parseFloat(value);
							} else if(name == "dirx") {
								remote_player_dirx = parseFloat(value);
							} else if(name == "dirz") {
								remote_player_dirz = parseFloat(value);
							} else if(name == "jump") {
								remote_player_jump = (value == "1");
							} else if(name == "crouch") {
								remote_player_crouch = (value == "1");
							} else if(name == "attack") {
								remote_player_attack = (value == "1");
							} else if(name == "grab") {
								remote_player_grab = (value == "1");
							} else if(name == "item") {
								remote_player_item = (value == "1");
							} else if(name == "drop") {
								remote_player_drop = (value == "1");
							} else if(name == "roll") {
								remote_player_roll = (value == "1");
							} else if(name == "offwall") {
								remote_player_jumpoffwall = (value == "1");
							} else if(name == "activeblock") {
								remote_player_activeblock = (value == "1");
							} else if(name == "blood_damage") {
								remote_player_blood_damage = parseFloat(value);
							} else if(name == "blood_health") {
								remote_player_blood_health = parseFloat(value);
							} else if(name == "block_health") {
								remote_player_block_health = parseFloat(value);
							} else if(name == "temp_health") {
								remote_player_temp_health = parseFloat(value);
							} else if(name == "permanent_health") {
								remote_player_permanent_health = parseFloat(value);
							} else if(name == "knocked_out") {
								remote_player_knocked_out = parseInt(value);
							} else if(name == "lives") {
								remote_player_lives = parseInt(value);
							} else if(name == "blood_amount") {
								remote_player_blood_amount = parseFloat(value);
							} else if(name == "recovery_time") {
								remote_player_recovery_time = parseFloat(value);
							} else if(name == "roll_recovery_time") {
								remote_player_roll_recovery_time = parseFloat(value);
							} else if(name == "ragdoll_type") {
								remote_player_ragdoll_type = parseInt(value);
							} else if(name == "remove_blood") {
								remote_player_remove_blood = (value == "1");
							} else if(name == "cut_throat") {
								remote_player_cut_throat = (value == "1");
							} else if(name == "state") {
								remote_player_state = parseInt(value);
							}
						}

						int num_players = remote_players.size();

						for(int i = 0; i< num_players; i++) {
							MovementObject@ temp_char = remote_players[i];
							Object@ char_obj = ReadObjectFromID(temp_char.GetID());
							ScriptParams@ params = char_obj.GetScriptParams();
							if(params.HasParam("Name")) {
								string name_str = params.GetString("Name");
								if(remote_player_name == name_str) {
									remote_player_id = i;
									break;
								}
							}
						}

						PrintDebug("id: " + remote_player_id + "\tname: " + remote_player_name + "\n");

						if(remote_player_id != -1) {
							MovementObject@ remote_player = remote_players[remote_player_id];

							if(remote_player is null) {
								continue;
							}

							if(remote_player.GetID() != -1) {
								remote_player.Execute("lives = "+remote_player_lives+";");
								remote_player.Execute("cut_throat = "+remote_player_cut_throat+";");
								remote_player.Execute("blood_amount = "+remote_player_blood_amount+";");
								remote_player.Execute("recovery_time = "+remote_player_recovery_time+";");
								remote_player.Execute("roll_recovery_time = "+remote_player_roll_recovery_time+";");

								if(remote_player_remove_blood) {
									remote_player.Execute("this_mo.rigged_object().CleanBlood();");
								}

								remote_player.Execute("SetKnockedOut("+remote_player_knocked_out+");");

								remote_player.Execute("blood_damage = "+remote_player_blood_damage+";");
								remote_player.Execute("blood_health = "+remote_player_blood_health+";");
								remote_player.Execute("block_health = "+remote_player_block_health+";");
								remote_player.Execute("temp_health = "+remote_player_temp_health+";");
								remote_player.Execute("permanent_health = "+remote_player_permanent_health+";");

								remote_player.Execute("MPWantsToJump = "+remote_player_jump+";");
								remote_player.Execute("MPWantsToCrouch = "+remote_player_crouch+";");
								remote_player.Execute("MPWantsToAttack = "+remote_player_attack+";");
								remote_player.Execute("MPWantsToGrab = "+remote_player_grab+";");
								remote_player.Execute("MPWantsToItem = "+remote_player_item+";");
								remote_player.Execute("MPWantsToDrop = "+remote_player_drop+";");
								remote_player.Execute("MPWantsToRoll = "+remote_player_roll+";");
								remote_player.Execute("MPWantsToJumpOffWall = "+remote_player_jumpoffwall+";");
								remote_player.Execute("MPActiveBlock = "+remote_player_activeblock+";");

								if(remote_player_dirx == 0.0f) {
									remote_player.Execute("dir_x = 0.0f;");
								} else{
									remote_player.Execute("dir_x = "+ remote_player_dirx +";");
								}
								if(remote_player_dirz == 0.0f) {
									remote_player.Execute("dir_z = 0.0f;");
								} else{
									remote_player.Execute("dir_z = "+ remote_player_dirz +";");
								}

								remote_player.position.x = remote_player_posx;
								remote_player.position.y = remote_player_posy;
								remote_player.position.z = remote_player_posz;

								// Only set the states manually to ragdoll and unragdoll characters when they are in
								// the wrong state. Syncing all states disrupts the fighting.
								int old_state = remote_player.GetIntVar("state");
								if(remote_player_state != old_state) {
									if(remote_player_state == _ragdoll_state) {
										remote_player.Execute("ragdoll_counter++;");

										// It causes massive problems when a character is only ragdolled for some ms, so
										// only sync ragdoll states that last more than 1 or 2 updates.
										if (remote_player.GetIntVar("ragdoll_counter") > 7) {
											PrintDebug("Ragdolling player\n");

											remote_player.Execute("Ragdoll("+remote_player_ragdoll_type+");");
										}
									} else if(old_state == _ragdoll_state) {
										PrintDebug("UnRagdolling player\n");

										remote_player.Execute("ragdoll_counter = 0;");
										remote_player.Execute("SetState(_movement_state);");
										remote_player.Execute("ApplyIdle(5.0f,true);");
									}
								}
							}
						}
					} else if(first_level[a][0][1] == "UpdateSelf") {
						int second_level_size = first_level[a].size();

						float player_blood_damage;
						float player_blood_health;
						float player_block_health;
						float player_temp_health;
						float player_permanent_health;
						int player_knocked_out;
						int player_lives;
						float player_blood_amount;
						float player_recovery_time;
						float player_roll_recovery_time;
						int player_ragdoll_type;
						bool player_remove_blood;
						bool player_cut_throat;

						for (int b = 0; b < second_level_size; b++) {
							string name = first_level[a][b][0];
							string value = first_level[a][b][1];

							if(name == "blood_damage") {
								player_blood_damage = parseFloat(value);
							} else if(name == "blood_health") {
								player_blood_health = parseFloat(value);
							} else if(name == "block_health") {
								player_block_health = parseFloat(value);
							} else if(name == "temp_health") {
								player_temp_health = parseFloat(value);
							} else if(name == "permanent_health") {
								player_permanent_health = parseFloat(value);
							} else if(name == "knocked_out") {
								player_knocked_out = parseInt(value);
							} else if(name == "lives") {
								player_lives = parseInt(value);
							} else if(name == "blood_amount") {
								player_blood_amount = parseFloat(value);
							} else if(name == "recovery_time") {
								player_recovery_time = parseFloat(value);
							} else if(name == "roll_recovery_time") {
								player_roll_recovery_time = parseFloat(value);
							} else if(name == "ragdoll_type") {
								player_ragdoll_type = parseInt(value);
							} else if(name == "remove_blood") {
								player_remove_blood = (value == "1");
							} else if(name == "cut_throat") {
								player_cut_throat = (value == "1");
							}
						}

						//PrintDebug("Self update\n");
						int player_id = GetPlayerCharacterID();

						if(player_id == -1) {
							continue;
						}

						MovementObject@ char = ReadCharacter(player_id);
						char.Execute("blood_damage = "+player_blood_damage+";");
						char.Execute("blood_health = "+player_blood_health+";");
						char.Execute("block_health = "+player_block_health+";");
						char.Execute("temp_health = "+player_temp_health+";");
						char.Execute("permanent_health = "+player_permanent_health+";");
						char.Execute("knocked_out = "+player_knocked_out+";");
						char.Execute("lives = "+player_lives+";");
						char.Execute("blood_amount = "+player_blood_amount+";");
						char.Execute("recovery_time = "+player_recovery_time+";");
						char.Execute("roll_recovery_time = "+player_roll_recovery_time+";");
						char.Execute("cut_throat = "+player_cut_throat+";");

						if(player_remove_blood) {
							char.Execute("this_mo.rigged_object().CleanBlood();");
						}
					} else if(first_level[a][0][1] == "Message") {
						int second_level_size = first_level[a].size();

						string remote_username;
						string text;
						string notif;

						for (int b = 0; b < second_level_size; b++) {
							string name = first_level[a][b][0];
							string value = first_level[a][b][1];
							if(name == "name") {
								remote_username = value;
							} else if(name == "text") {
								text = value;
							} else if(name == "notif") {
								notif = value;
							}
						}

						text = join( text.split( "%25" ), "%" );
						text = join( text.split( "%22" ), "\"" );
						text = join( text.split( "%23" ), "#" );
						text = join( text.split( "%26" ), "&" );
						text = join( text.split( "%27" ), "'" );
						text = join( text.split( "%3d" ), "=" );
						text = join( text.split( "%5c" ), "\\" );

						PrintDebug("Adding chat message: " + "addChat(\""+remote_username+"\",\""+text+"\","+notif+")" + "\n");
						gui.Execute(chat_id,"addChat(\""+remote_username+"\",\""+text+"\","+notif+")");
					} else if(first_level[a][0][1] == "LoadPosition") {
						PlaySound("Data/Sounds/ambient/amb_canyon_hawk_1.wav");
						PrintDebug("Received loadpostion message." + "\n");

						//Reset velocity to avoid being crunched to death.
						MovementObject@ char = ReadCharacter(0);
						char.velocity = vec3(0);

						int second_level_size = first_level[a].size();
						for (int b = 0; b < second_level_size; b++) {
							string name = first_level[a][b][0];
							string value = first_level[a][b][1];

							if(name == "posx") {
								char.position.x = parseFloat(value);
							} else if(name == "posy") {
								char.position.y = parseFloat(value);
							} else if(name == "posz") {
								char.position.z = parseFloat(value);
							}
						}

						// Reset animations to avoid the strange hands.
						char.Execute("ResetSecondaryAnimation();");
					}
				}
			}

			callback = gui.GetCallback(client_connect_id);
		}
	}
}

void HandleChat() {
	if(!connected_to_server) {
		return;
	}

	string chat_callback = gui.GetCallback(chat_id);

	while(chat_callback != "") {
		//PrintDebug("chat callback:" + chat_callback + "\n");

		if(chat_callback == '!unfocus') {
			has_chat_gui = false;
			break;
		}

		string filtered = join( chat_callback.split( "\"" ), "" );
		string message = "type=Message" + "&name=" + username + "&uid=" + client_uid + "&text=" + filtered ;
		PrintDebug(message + "\n");
		gui.Execute(client_connect_id,"sendUpdate(\""+message+"\")");
		has_chat_gui = false;
		chat_callback = gui.GetCallback(chat_id);
	}
}

void DrawUsernames() {
	if(!connected_to_server) {
		return;
	}

	int num = GetNumCharacters();
	for(int i=0; i<num; ++i) {
		MovementObject@ char = ReadCharacter(i);
		Object @obj = ReadObjectFromID(char.GetID());
		ScriptParams@ params = obj.GetScriptParams();
		if(!params.HasParam("Name")) {
			return;
		}
		string new_string = params.GetString("Name");

		int num_canvases = int(dialogue_text_canvases.size());
		int assigned_canvas = -1;
		for(int j=0; j<num_canvases; ++j) {
			if(dialogue_text_canvases[j].obj_id == obj.GetID()) {
				assigned_canvas = j;
			}
		}
		if(assigned_canvas == -1) {
			dialogue_text_canvases.resize(num_canvases+1);
			dialogue_text_canvases[num_canvases].obj_id = obj.GetID();
			dialogue_text_canvases[num_canvases].text = "";
			dialogue_text_canvases[num_canvases].canvas_id = level.CreateTextElement();
			TextCanvasTexture @text = level.GetTextElement(dialogue_text_canvases[num_canvases].canvas_id);
			text.Create(256, 256);
			assigned_canvas = num_canvases;
		}
		DialogueTextCanvas @assigned = dialogue_text_canvases[assigned_canvas];
		TextCanvasTexture @text = level.GetTextElement(assigned.canvas_id);
		if(assigned.text != new_string) {
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
			text.AddText(new_string, small_style, UINT32MAX);
			text.UploadTextCanvasToTexture();
			assigned.text = new_string;
		}
		vec3 name_text_pos = vec3(char.position.x, char.position.y + 1.5f, char.position.z);
		text.DebugDrawBillboard(name_text_pos, obj.GetScale().x, _delete_on_update);
	}
}

void SendUpdate() {
	if(connected_to_server) {
		delay -= time_step;
		if(delay <= 0.0f) {
			MovementObject@ char = ReadCharacter(0);

			string message = "type=Update&uid=" + client_uid +
			"&posx=" + char.position.x +
			"&posy=" + char.position.y +
			"&posz=" + char.position.z +
			"&dirx=" + char.GetFloatVar("dir_x") +
			"&dirz=" + char.GetFloatVar("dir_z") +
			"&crouch=" + char.GetBoolVar("MPWantsToCrouch") +
			"&jump=" + char.GetBoolVar("MPWantsToJump") +
			"&attack=" + char.GetBoolVar("MPWantsToAttack") +
			"&grab=" + char.GetBoolVar("MPWantsToGrab") +
			"&item=" + char.GetBoolVar("MPWantsToItem") +
			"&drop=" + char.GetBoolVar("MPWantsToDrop") +
			"&roll=" + char.GetBoolVar("MPWantsToRoll") +
			"&offwall=" + char.GetBoolVar("MPWantsToJumpOffWall") +
			"&activeblock=" + char.GetBoolVar("MPActiveBlock") +
			"&blood_damage=" + char.GetFloatVar("blood_damage") +
			"&blood_health=" + char.GetFloatVar("blood_health") +
			"&block_health=" + char.GetFloatVar("block_health") +
			"&temp_health=" + char.GetFloatVar("temp_health") +
			"&permanent_health=" + char.GetFloatVar("permanent_health") +
			"&knocked_out=" + char.GetIntVar("knocked_out") +
			"&lives=" + char.GetIntVar("lives") +
			"&blood_amount=" + char.GetFloatVar("blood_amount") +
			"&recovery_time=" + char.GetFloatVar("recovery_time") +
			"&roll_recovery_time=" + char.GetFloatVar("roll_recovery_time") +
			"&ragdoll_type=" + char.GetIntVar("ragdoll_type") +
			"&blood_delay=" + char.GetIntVar("blood_delay") +
			"&cut_throat=" + char.GetBoolVar("cut_throat") +
			"&state=" + char.GetIntVar("state");

			char.Execute("MPWantsToRoll = false;");
			char.Execute("MPWantsToJumpOffWall = false;");
			char.Execute("MPActiveBlock = false;");

			gui.Execute(client_connect_id,"sendUpdate(\""+message+"\")");
			delay += frequency;
		}
	}
}

void Disconnect() {
	connected_to_server = false;
	MovementObject@ char = ReadCharacter(0);
	char.Execute("MPIsConnected = false;");

	// Notify player.
	gui.Execute(chat_id,"addChat('System', 'Connection to server lost.', true)");

	// Remove other players.
	int num = GetNumCharacters();
	for(int i = 1; i<num; i++) {
		MovementObject@ other_char = ReadCharacter(i);
		PrintDebug("Delete character" + other_char.GetID() + "\n");
		DeleteObjectID(other_char.GetID());
	}
	remote_players.resize(0);

	//Every known character needs to be removed or else the situationawareness script will check the nonexisting movementobjects
	char.Execute("situation.clear();");
}

bool HasOGMPFocus() {
	if(showing_playerlist || has_client_connect_gui) {
		return true;
	}

	if((has_gui || connected_to_server) && (!connected_to_server || has_chat_gui)) {
		return true;
	}

	return false;
}

void PrintDebug(string str) {
	if(debug) {
		Print(str);
	}
}
