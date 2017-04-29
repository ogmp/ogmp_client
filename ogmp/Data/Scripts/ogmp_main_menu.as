#include "menu_common.as"
#include "music_load.as"
#include "common_data.as"

MusicLoad ml("Data/Music/menu.xml");

IMGUI imGUI;

uint socket = SOCKET_ID_INVALID;
uint main_socket = SOCKET_ID_INVALID;

string username = "";

bool HasFocus() {
    return false;
}

void Initialize() {

    // Start playing some music
    PlaySong("overgrowth_main");

    // We're going to want a 100 'gui space' pixel header/footer
    imGUI.setHeaderHeight(200);
    imGUI.setFooterHeight(200);

    // Actually setup the GUI -- must do this before we do anything
    imGUI.setup();
    setBackGround();
	AddClientConnectUI();
	IMDivider header_divider( "header_div", DOHorizontal );
	AddTitleHeader("Overgrowth Multiplayer Mod", header_divider);
	imGUI.getHeader().setElement(header_divider);
    AddBackButton();
}

void AddClientConnectUI(){
	vec2 menu_size(1000, 500);
	string white_background = "Textures/ui/menus/main/white_square.png";
	vec4 background_color(0,0,0,0.5);
	vec2 connect_button_size(1000, 60);
	float button_size_offset = 10.0f;
	
	IMContainer menu_container(menu_size.x, menu_size.y);
	IMDivider menu_divider("menu_divider", DOVertical);
	menu_container.setElement(menu_divider);
	
	IMText username_label("Your username will be \"" + username + "\"", client_connect_font);
	menu_divider.append(username_label);
	
	for(uint i = 0; i < server_retriever.online_servers.size(); i++){
		//Connect button
		IMContainer button_container(connect_button_size.x, connect_button_size.y);
		button_container.addLeftMouseClickBehavior(IMFixedMessageOnClick("connect", i), "");
		menu_divider.append(button_container);
		
		IMText connect_text("Connect to " + server_retriever.online_servers[i].address + " latency: " + server_retriever.online_servers[i].latency, client_connect_font);
		connect_text.addMouseOverBehavior(mouseover_fontcolor, "");
		connect_text.setZOrdering(3);
		button_container.setElement(connect_text);
		
		IMImage button_background(white_background);
		button_background.setZOrdering(0);
		button_background.setSize(connect_button_size - button_size_offset);
		button_background.setColor(vec4(0,0,0,0.75));
		button_container.addFloatingElement(button_background, "button_background", vec2(button_size_offset / 2.0f));
	}
	
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
	background.setSize(menu_size);
	menu_container.addFloatingElement(background, "background", vec2(0));
	imGUI.getMain().setSize(vec2(2560, 1000));
	/*imGUI.getMain().setAlignment(CACenter, CACenter);*/
	imGUI.getMain().setElement(menu_container);
}

void Dispose() {
	imGUI.clear();
}

bool CanGoBack() {
    return true;
}

void Update() {

    // Do the general GUI updating
    imGUI.update();
	UpdateController();
	UpdateKeyboardMouse();
	// process any messages produced from the update
    while( imGUI.getMessageQueueSize() > 0 ) {
        IMMessage@ message = imGUI.getNextMessage();

        Log( info, "Got processMessage " + message.name );

        if( message.name == "Back" )
        {
            this_ui.SendCallback( "back" );
        }
        else if( message.name == "run_file" ) 
        {
            this_ui.SendCallback(message.getString(0));
        }
		else if( message.name == "shift_menu" ){
			ShiftMenu(message.getInt(0));
		}
    }
}

void Resize() {
    imGUI.doScreenResize(); // This must be called first
    setBackGround();
}

void ScriptReloaded() {
    // Clear the old GUI
    imGUI.clear();
    // Rebuild it
    Initialize();

}

void DrawGUI() {
    imGUI.render();
}

void Draw() {
}

void Init(string str) {
}
