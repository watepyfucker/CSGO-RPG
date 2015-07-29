/*===========================


			CSGO RPGMOD
				--BorderRPG


============================*/

/*
log:
	15/7/26:Create on github
*/

#include <sourcemod>
#include <sdktools>
#include <adminmenu>
#include <cstrike>
#include <sdkhooks>

#define MAXPLAYER 65
#define NEXTLVXP(%1) (GetConVarInt(g_lvup_need_xp) * g_lv[%1])
#define KILL_T_XP		GetConVarInt(g_kill_T_xp)
#define KILL_T_MONEY 	GetConVarInt(g_kill_T_money)

new const String:g_job_name[][] = {"无职业", "精灵", "游侠", "医师"}

//玩家属性
new g_lv[MAXPLAYER]					//等级
new g_xp[MAXPLAYER]					//经验值
new g_sp[MAXPLAYER]					//技能点
new g_mete[MAXPLAYER]				//转生

new g_str[MAXPLAYER]				//力量
new g_dex[MAXPLAYER]				//敏捷
new g_int[MAXPLAYER]				//智力
new g_hea[MAXPLAYER]				//生命
new g_end[MAXPLAYER]				//耐力
new g_luc[MAXPLAYER]				//幸运

new g_money[MAXPLAYER]				//金钱
new g_job[MAXPLAYER]				//职业
new g_mana[MAXPLAYER]				//魔法值

//Save
new Handle:g_Rpg_Save				//Save
new String:g_Save_Path[185]		//存储路径

//Vars
new g_Player_RespawnTime[MAXPLAYER]	//复活时间
new g_AliveTeam									//CT存活

//Bool
new bool:g_IsCrit[MAXPLAYER]		//有没有暴击

//Convars
new Handle:g_AutoSaveTime				//自动储存的时间
new Handle:g_RespawnTime_CT				//CT复活时间
new Handle:g_lvup_need_xp				//升级需要的经验值(基础量)
new Handle:g_kill_T_xp						//杀死T获得的经验(基础量)
new Handle:g_kill_T_money				//杀死T获得的金钱(基础量)
new Handle:g_lvup_get_sp					//升级获得的技能点
new Float:g_RestoreTime[MAXPLAYER]				//生命恢复计时

new Handle:g_str_max						//力量最大值
new Handle:g_dex_max						//敏捷最大值
new Handle:g_int_max						//智力最大值
new Handle:g_hea_max						//生命最大值
new Handle:g_end_max						//耐力最大值
new Handle:g_luc_max						//幸运最大值
new Handle:g_str_effect_damage		//力量增加的伤害
new Handle:g_dex_effect_speed			//敏捷增加的速度
new Handle:g_hea_add_health				//生命增加的最大值
new Handle:g_end_reduce_damage		//耐力减伤倍数
new Handle:g_end_restore_time		//耐力恢复生命时间
new Handle:g_int_effect_MP				//智力增加的MP上限及恢复速度(增加每秒恢复量 = 增加MP上限/100)
new Handle:g_luc_dodge_chance		//幸运闪避几率
new Handle:g_luc_crit_chance		//幸运暴击几率
new Handle:g_luc_drop_chance		//幸运掉宝几率

new Handle:g_crit_multi				//暴击伤害倍数
new Handle:g_restore_deftime		//生命恢复默认时间
new Handle:g_restore_point			//每次恢复多少点HP

new Handle:g_base_mana						//基础魔法值
//Timers
new Handle:g_PlayerThinkTimer[MAXPLAYER]	//Think
new Handle:g_PlayerAutoSaveTimer					//Autosave

//Mod info
public Plugin:myinfo=
{
	name = "BorderRPG",
	author = "FUCKER",
	description = "BorderRPG mod",
	version = "0.0",
	url = "https://github.com/watepyfucker/CSGO-RPG/"
}

public OnPluginStart()
{
	new String:Game_Name[16];
	GetGameFolderName(Game_Name, sizeof(Game_Name))
	if(!StrEqual(Game_Name, "csgo", false))
		SetFailState("不是CSGO你玩JB")
	
	//读取字典
	LoadTranslations("BorderRPG.phrases");
	
	//初始化
	EventsInit()
	CvarsInit()
	CommandInit()
	FileDataInit()
}

/*
===================================
		
		   初始化
		
===================================
*/

public FileDataInit()
{
	g_Rpg_Save = CreateKeyValues("BorderRPG Save");
	BuildPath(Path_SM, g_Save_Path, 184, "data/BorderRPG_Save.ini");
	
	if (FileExists(g_Save_Path))
		FileToKeyValues(g_Rpg_Save, g_Save_Path);
	else
	{
		PrintToServer("[BorderRPG]%T", "Cant_Find_Save_File", LANG_SERVER, g_Save_Path);
		KeyValuesToFile(g_Rpg_Save, g_Save_Path)
	}
}

public EventsInit()
{
	HookEvent("round_start", Event_RoundStart)
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre)
	HookEvent("player_spawn", Event_PlayerSpawn)
	HookEvent("player_death", Event_PlayerDeath)
}

public CvarsInit()
{
	g_AutoSaveTime	=			CreateConVar("rpg_autosavetime", "30.0", "多久存一次档");
	g_RespawnTime_CT = 		CreateConVar("rpg_respawntime_ct", "60", "CT死亡后多久复活");
	g_lvup_need_xp =		    CreateConVar("rpg_xp_lvup", "100", "升级所需经验值(基础量)");
	g_kill_T_xp =			    CreateConVar("rpg_kill_t_get_xp", "10", "杀死T获得的经验(基础量)");
	g_kill_T_money = 			CreateConVar("rpg_kill_t_get_money", "10", "杀死T获得的金钱(基础量)");
	g_lvup_get_sp = 			CreateConVar("rpg_get_sp_lvup", "5", "升级获得的技能点")
	
	g_str_max = 					CreateConVar("rpg_str_max", "2000", "力量最大值")
	g_int_max = 					CreateConVar("rpg_int_max", "2000", "智力最大值")
	g_dex_max = 					CreateConVar("rpg_dex_max", "2000", "敏捷最大值")
	g_hea_max = 					CreateConVar("rpg_hea_max", "2000", "生命最大值")
	g_end_max = 					CreateConVar("rpg_end_max", "2000", "耐力最大值")
	g_luc_max = 					CreateConVar("rpg_luc_max", "2000", "幸运最大值")
	
	g_str_effect_damage = 				CreateConVar("rpg_str_effect_damage", "0.25", "力量增加的伤害")
	g_end_restore_time = 				CreateConVar("rpg_end_restore_time","0.0025","耐力减少的生命恢复时间")
	g_end_reduce_damage = 				CreateConVar("rpg_end_reduce_damage", "0.01", "耐力减伤倍数")
	g_hea_add_health = 					CreateConVar("rpg_hea_add_health", "10", "生命增加的最大值")
	g_dex_effect_speed = 				CreateConVar("rpg_dex_effect_speed","0.002", "敏捷增加的速度")
	g_int_effect_MP = 					CreateConVar("rpg_int_effect_MP", "1000", "智力增加的MP上限及恢复速度")
	g_luc_dodge_chance = 				CreateConVar("rpg_luc_dodge_chance","0.025","幸运增加的躲避几率")
	g_luc_crit_chance = 				CreateConVar("rpg_luc_crit_chance","0.025","幸运增加的暴击几率")
	g_luc_drop_chance = 				CreateConVar("rpg_luc_drop_chance","0.013","幸运增加的掉宝几率")
	
	g_crit_multi = 					CreateConVar("rpg_crit_multi","2.00","暴击伤害倍数")
	g_restore_deftime = 			CreateConVar("rpg_restore_deftime","5.50","生命恢复默认时间")
	g_restore_point = 				CreateConVar("rpg_restore_point","1","每次恢复多少HP")
	
	g_base_mana = 				CreateConVar("rpg_base_mana", "10000", "基础魔法值")
}

public CommandInit()
{
	AddCommandListener(Command_JoinTeam, "jointeam"); 
	AddCommandListener(Command_Test, "sm_testa");
	RegConsoleCmd("sm_save",	Command_SaveUserData);
}

/*
===================================
		
		   各种事件
		
===================================
*/

//地图开始
public OnMapStart()
{
	g_PlayerAutoSaveTimer = CreateTimer(GetConVarFloat(g_AutoSaveTime), Timer_PlayerAutoSave, _, TIMER_REPEAT);
	ServerCommand("exec server.cfg")
	for(int i = 0;i < 15;i++)
	{
		ServerCommand("bot_add_t");
	}
}

public OnMapEnd()
{
	KillTimer(g_PlayerAutoSaveTimer)
	g_PlayerAutoSaveTimer = INVALID_HANDLE
}

//回合开始
public Action:Event_RoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
	g_AliveTeam = 0
	//1 白 2深红 3紫 4绿 5淡绿 6橄榄绿 7红淡一点 8淡紫 9淡黄 10咖啡色
	PrintToChatAll("\x01 \x03[RPGmod]\x02%T", "GameStart", LANG_SERVER);
	PrintHintTextToAll("<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","GameStart",LANG_SERVER);
	//PrintCenterTextAll("<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","GameStart",LANG_SERVER);
}

//玩家复活
public Action:Event_PlayerSpawn(Handle:event,const String:event_name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	g_RestoreTime[client] = GetConVarFloat(g_restore_deftime);
	if(GetClientTeam(client) == CS_TEAM_CT)
	{
		g_Player_RespawnTime[client] = -1
		g_AliveTeam++
		
		//设置玩家属性
		SetEntityHealth(client, 100 + GetConVarInt(g_hea_add_health) * g_hea[client] )
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 
		GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue") * (1.0 + g_dex[client] * GetConVarFloat(g_dex_effect_speed))); 
		
		PrintToChat(client, "speed:%f", GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue"))
		
	}
	return Plugin_Continue;
}

//玩家进入服务器
public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	if(!IsFakeClient(client))
	{
		rpg_Reset_Player_Vars(client)
		rpg_Client_Load_Data(client)
		g_PlayerThinkTimer[client] = CreateTimer(1.0, Timer_PlayerThink, client, TIMER_REPEAT);
	}
}

//玩家连接
public OnClientConnected(client)
{
	rpg_Reset_Player_Vars(client)
}

//玩家断线
public OnClientDisconnect(client)
{
	if(!IsFakeClient(client))
	{
		if(g_PlayerThinkTimer[client] != INVALID_HANDLE)
		{
			KillTimer(g_PlayerThinkTimer[client])
			g_PlayerThinkTimer[client] = INVALID_HANDLE;
		}
	}
}

//设置伤害用(BOT也适用噢)
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(!IsClientConnected(attacker) || attacker < 0)
		return Plugin_Continue
	
	if(g_luc[victim] > 1)
	{
		new dodgec = GetRandomInt(0,100);
		new Float:dodge = g_luc[victim] * GetConVarFloat(g_luc_dodge_chance);
	
		if(dodgec <= dodge)
		{
			damage = 0.0;
			PrintHintText(victim, "<font color='#FF6600'>%T</font>", "Dodge",LANG_SERVER)
			return Plugin_Changed
		}
	}
	
	new Float:dmg = damage;
	new Float:strb = GetConVarFloat(g_str_effect_damage);
	new Float:endb = GetConVarFloat(g_end_reduce_damage);
	new Float:dmgout = dmg + (g_str[attacker] * strb);
	new Float:rdmg;
	
	if(g_end[victim] > 0)
		rdmg = dmgout - dmgout / (g_end[victim]*endb);
	else
		rdmg = dmgout;
	
	if(g_luc[attacker] > 1)
	{
		new critc = GetRandomInt(0,100);
		new Float:crit = g_luc[attacker] * GetConVarFloat(g_luc_crit_chance);
		if(critc <= crit)
		{
			g_IsCrit[attacker] = true;
			rdmg = rdmg * GetConVarFloat(g_crit_multi);
		}
	}
	
	damage = rdmg;
	return Plugin_Changed;
}

//玩家伤害
public Action:Event_PlayerHurt(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new damage = GetEventInt(event, "dmg_health");
	
	if(!IsClientConnected(attacker) || IsFakeClient(attacker) || attacker < 0)
		return Plugin_Continue;
	
	if(g_IsCrit[attacker])
	{
		g_IsCrit[attacker] = false;
		PrintHintText(attacker, "<font color='#FF0000'>%T</font>", "CRIT",LANG_SERVER,damage);
	}
	else PrintHintText(attacker, "<font color='#FF6600'>    -%dHP</font>", damage);
	
	return Plugin_Continue;
}

//玩家死亡
public Action:Event_PlayerDeath(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new killer = GetClientOfUserId(GetEventInt(event, "attacker"));
	new teamA = GetClientTeam(victim);
	new teamB = GetClientTeam(killer);
	
	//CT被杀
	if(teamA == CS_TEAM_CT && !IsFakeClient(victim))
	{
		g_AliveTeam--;
		g_Player_RespawnTime[victim] = GetConVarInt(g_RespawnTime_CT)
	}
	
	//CT杀T
	if(teamB == CS_TEAM_CT && teamA == CS_TEAM_T && !IsFakeClient(killer))
	{
		new GetXp = KILL_T_XP
		new GetMoney = KILL_T_MONEY
		g_xp[killer] += GetXp
		g_money[killer] += GetMoney
		PrintToChat(killer,"\x01 \x03[RPGmod]\x02%T", "Kill_T_Get_Text", LANG_SERVER, GetXp, GetMoney);
	}

	return Plugin_Continue;
}

/*
===================================
		
			Timer
		
===================================
*/
//Player Think
public Action:Timer_PlayerThink(Handle:Timer, any:client)
{
	if(g_xp[client] >= NEXTLVXP(client))
	{
		g_xp[client] -= NEXTLVXP(client)
		g_lv[client] ++
		g_sp[client] += GetConVarInt(g_lvup_get_sp)
		PrintToChat(client,"\x01 \x03[RPGmod]\x02%T", "LevelUp",LANG_SERVER, g_lv[client]);
	}
	
	if(g_end[client] > 1)
	{
		if(g_RestoreTime[client] > 0 && IsPlayerAlive(client))
		{
			g_RestoreTime[client] -= g_end[client] * GetConVarFloat(g_end_restore_time)
		}
		if(!g_RestoreTime[client] && IsPlayerAlive(client) && GetClientHealth(client) < (100 + GetConVarInt(g_hea_add_health) * g_hea[client]))
		{
			g_RestoreTime[client] = GetConVarFloat(g_restore_deftime)
			SetEntityHealth(client, GetClientHealth(client) + GetConVarInt(g_restore_point))
		}
	}
	
	if(g_Player_RespawnTime[client] > 0 && g_AliveTeam > 0)
	{
		g_Player_RespawnTime[client] --
		PrintHintText(client, "<font color='#66ccff'>[RPGMOD]</font><font color='#66ff00'>%T</font>", "Dead_CT",LANG_SERVER, g_Player_RespawnTime[client])
	}
	
	if(g_Player_RespawnTime[client] <= 0)
	{
		g_Player_RespawnTime[client] = -1
		CS_RespawnPlayer(client)
	}
}

public Action:Timer_PlayerAutoSave(Handle:Timer)
{
	for(new i = 1; i < GetMaxClients() ; i++)
	{
		if(IsClientConnected(i) && !IsFakeClient(i))
			rpg_Client_Save_Data(i)
	}
}

/*
===================================
		
		   客户端命令
		
===================================
*/

//Jointeam
public Action:Command_JoinTeam(client, const String:command[], args)
{
	if (!IsClientConnected(client))
        return Plugin_Continue; 
	
	CS_SwitchTeam(client, CS_TEAM_CT)
	return Plugin_Stop;
}

//
public Action:Command_Test(client, const String:command[], args)
{
	rpg_Strip_Weapon(client, 0)
	rpg_Give_Weapon_Skin(client, "weapon_ak47", 344)
}

public Action:Command_SaveUserData(client, args)
{
	if (IsClientConnected(client))
		rpg_Client_Save_Data(client)
	
	return Plugin_Continue; 
}

//Button
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(IsFakeClient(client))
		return Plugin_Continue
	
	if (buttons & IN_SPEED)
		MenuShow_MainMenu(client)
	
	return Plugin_Continue
}
/*
===================================
		
		   Menu
		
===================================
*/

//Main Menu
public Action:MenuShow_MainMenu(id)
{
	if(IsFakeClient(id))
		return Plugin_Handled;
	
	new Handle:menu = CreateMenu(MenuHandler_MainMenu);
	decl String:MenuTitle[200]
	Format(MenuTitle, sizeof(MenuTitle), "%T ", "MainMenu_Title", LANG_SERVER, 
	g_lv[id], g_money[id], g_job_name[g_job[id]], g_xp[id], NEXTLVXP(id), g_mete[id], g_sp[id], g_str[id], g_dex[id], g_hea[id], g_end[id], g_int[id], g_luc[id])
	
	//等级:Lv.%d 金钱:$%d 职业:%s \n经验:%d/%d 转生:%d转 属性点:%d \n力量:%d 敏捷:%d 生命:%d 耐力:%d 智力:%d 运气:%d
	SetMenuTitle(menu, MenuTitle)
	
	decl String:Item[64]
	Format(Item, sizeof(Item), "%T ", "SkillMenu_Select", LANG_SERVER);
	AddMenuItem(menu, "#Choice1", Item);
	Format(Item, sizeof(Item), "B ");
	AddMenuItem(menu, "#Choice2", Item);
	
	SetMenuExitButton(menu, false);
	DisplayMenu(menu, id, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public MenuHandler_MainMenu(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select) 
    {
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		if (!strcmp(info,"#Choice1")) 
			MenuShow_SkillMenu(param1);
	}
}

//Skill Menu
public Action:MenuShow_SkillMenu(id)
{
	if(IsFakeClient(id))
		return Plugin_Handled;
	
	new Handle:menu = CreateMenu(MenuHandler_SkillMenu);
	decl String:MenuTitle[200]
	Format(MenuTitle, sizeof(MenuTitle), "%T ", "SkillMenu_Title", LANG_SERVER, g_sp[id])
	
	SetMenuTitle(menu, MenuTitle)
	
	
	decl String:Item[64]
	Format(Item, sizeof(Item), "%T ", "SkillMenu_AddModule",LANG_SERVER,"StrName",LANG_SERVER, g_str[id], GetConVarInt(g_str_max));
	AddMenuItem(menu, "#Choice1", Item);
	Format(Item, sizeof(Item), "%T ", "SkillMenu_AddModule",LANG_SERVER,"DexName",LANG_SERVER, g_dex[id], GetConVarInt(g_dex_max));
	AddMenuItem(menu, "#Choice2", Item);
	Format(Item, sizeof(Item), "%T ", "SkillMenu_AddModule",LANG_SERVER,"IntName",LANG_SERVER,g_int[id], GetConVarInt(g_int_max));
	AddMenuItem(menu, "#Choice3", Item);
	Format(Item, sizeof(Item), "%T ", "SkillMenu_AddModule",LANG_SERVER,"HeaName",LANG_SERVER,g_hea[id], GetConVarInt(g_hea_max));
	AddMenuItem(menu, "#Choice4", Item);
	Format(Item, sizeof(Item), "%T ", "SkillMenu_AddModule",LANG_SERVER,"EndName",LANG_SERVER,g_end[id], GetConVarInt(g_end_max));
	AddMenuItem(menu, "#Choice5", Item);
	Format(Item, sizeof(Item), "%T ", "SkillMenu_AddModule",LANG_SERVER,"LucName",LANG_SERVER,g_luc[id], GetConVarInt(g_luc_max));
	AddMenuItem(menu, "#Choice6", Item);
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, id, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public MenuHandler_SkillMenu(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select) 
    {
		if(g_sp[param1] <= 0)
		{
			PrintHintText(param1,"<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","UseSPFailed",LANG_SERVER)
			return;
		}
		
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		new String:Skill_Name[6][16]
		new String:Skill_LANG_NAME[6][] = {"StrName", "DexName", "IntName", "HeaName", "EndName", "LucName"}
		
		for(new i = 0; i < 6 ; i ++)
			Format(Skill_Name[i], sizeof(Skill_Name), "%T", Skill_LANG_NAME[i], LANG_SERVER)
		
		
		//STR
		if (!strcmp(info,"#Choice1")) 
        {
			if(g_str[param1] >= GetConVarInt(g_str_max)) 
			{
				PrintHintText(param1,"<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","UseSpSkillMax",LANG_SERVER)
				return;
			}
			g_sp[param1] --
			g_str[param1] += 1
			PrintHintText(param1,"<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","UseSPSuccess",LANG_SERVER, Skill_Name[0], g_sp[param1])
			MenuShow_SkillMenu(param1);
		}
		
		//DEX
		else if (!strcmp(info,"#Choice2")) 
        {
			if(g_dex[param1] >= GetConVarInt(g_dex_max)) 
			{
				PrintHintText(param1,"<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","UseSpSkillMax",LANG_SERVER)
				return;
			}
			g_sp[param1] --
			g_dex[param1] += 1
			PrintHintText(param1,"<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","UseSPSuccess",LANG_SERVER, Skill_Name[1], g_sp[param1])
			MenuShow_SkillMenu(param1);
		}
		
		//INT
		else if (!strcmp(info,"#Choice3")) 
        {
			if(g_int[param1] >= GetConVarInt(g_int_max)) 
			{
				PrintHintText(param1,"<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","UseSpSkillMax",LANG_SERVER)
				return;
			}
			g_sp[param1] --
			g_int[param1] += 1
			PrintHintText(param1,"<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","UseSPSuccess",LANG_SERVER, Skill_Name[2], g_sp[param1])
			MenuShow_SkillMenu(param1);
		}
		
		//HEA
		else if (!strcmp(info,"#Choice4")) 
		{
			if(g_hea[param1] >= GetConVarInt(g_hea_max)) 
			{
				PrintHintText(param1,"<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","UseSpSkillMax",LANG_SERVER)
				return;
			}
			g_sp[param1] --
			g_hea[param1] += 1
			PrintHintText(param1,"<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","UseSPSuccess",LANG_SERVER, Skill_Name[3], g_sp[param1])
			MenuShow_SkillMenu(param1);
		}
		
		//END
		else if (!strcmp(info,"#Choice5")) 
        {
			if(g_end[param1] >= GetConVarInt(g_end_max)) 
			{
				PrintHintText(param1,"<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","UseSpSkillMax",LANG_SERVER)
				return;
			}
			g_sp[param1] --
			g_end[param1] += 1
			PrintHintText(param1,"<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","UseSPSuccess",LANG_SERVER, Skill_Name[4], g_sp[param1])
			MenuShow_SkillMenu(param1);
		}
		
		//LUC
		else if (!strcmp(info,"#Choice6")) 
        {
			if(g_luc[param1] >= GetConVarInt(g_luc_max)) 
			{
				PrintHintText(param1,"<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","UseSpSkillMax",LANG_SERVER)
				return;
			}
			g_sp[param1] --
			g_luc[param1] += 1
			PrintHintText(param1,"<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","UseSPSuccess",LANG_SERVER, Skill_Name[5], g_sp[param1])
			MenuShow_SkillMenu(param1);
		}
		
	}
}

/*
===================================
		
		   各种函数
		
===================================
*/
//存档
public rpg_Client_Save_Data(client)
{
	new String:Str_SteamID[32]
	Format(Str_SteamID, 31, "%d", GetSteamAccountID(client))
	KvJumpToKey(g_Rpg_Save, Str_SteamID, true);
	KvSetNum(g_Rpg_Save, "LV", g_lv[client]);KvSetNum(g_Rpg_Save, "EXP", g_xp[client]);
	KvSetNum(g_Rpg_Save, "SP", g_sp[client]);KvSetNum(g_Rpg_Save, "MONEY", g_money[client]);
	KvSetNum(g_Rpg_Save, "JOB", g_job[client]);KvSetNum(g_Rpg_Save, "METE", g_mete[client]);
	KvSetNum(g_Rpg_Save, "STR", g_str[client]);KvSetNum(g_Rpg_Save, "DEX", g_dex[client]);
	KvSetNum(g_Rpg_Save, "HEA", g_hea[client]);KvSetNum(g_Rpg_Save, "INT", g_int[client]);
	KvSetNum(g_Rpg_Save, "END", g_end[client]);KvSetNum(g_Rpg_Save, "LUC", g_luc[client]);
	
	KvRewind(g_Rpg_Save)
	KeyValuesToFile(g_Rpg_Save, g_Save_Path);
	PrintToChat(client,"\x01 \x03[RPGmod]\x02%T", "Player_Data_Saved",LANG_SERVER);
}

//读档
public rpg_Client_Load_Data(client)
{
	KvRewind(g_Rpg_Save)
	new String:Str_SteamID[32]
	Format(Str_SteamID, 31, "%d", GetSteamAccountID(client))
	if(!KvJumpToKey(g_Rpg_Save, Str_SteamID))
		PrintToServer("%s", Str_SteamID);
	
	g_lv[client] = KvGetNum(g_Rpg_Save, "LV", 1); g_xp[client] = KvGetNum(g_Rpg_Save, "EXP", 0);
	g_sp[client] = KvGetNum(g_Rpg_Save, "SP", GetConVarInt(g_lvup_get_sp)); 
	g_xp[client] = KvGetNum(g_Rpg_Save, "EXP", 0); g_money[client] = KvGetNum(g_Rpg_Save, "MONEY", 0);
	g_job[client] = KvGetNum(g_Rpg_Save, "JOB", 0); g_mete[client] = KvGetNum(g_Rpg_Save, "METE", 0);
	
	g_str[client] = KvGetNum(g_Rpg_Save, "STR", 0); g_dex[client] = KvGetNum(g_Rpg_Save, "DEX", 0)
	g_hea[client] = KvGetNum(g_Rpg_Save, "HEA", 0); g_int[client] = KvGetNum(g_Rpg_Save, "INT", 0)
	g_end[client] = KvGetNum(g_Rpg_Save, "END", 0); g_luc[client] = KvGetNum(g_Rpg_Save, "LUC", 0);
	
	PrintToConsole(client, "[RPGmod]%T", "Player_Data_Loaded", LANG_SERVER)
	KvGoBack(g_Rpg_Save)

}

//重置玩家变量
public rpg_Reset_Player_Vars(id)
{
	g_lv[id] = 1; g_xp[id] = 0;g_sp[id] = GetConVarInt(g_lvup_get_sp) * g_lv[id];g_mete[id] = 0; 
	g_str[id] = 0; g_dex[id] = 0; g_hea[id] = 0;g_int[id] = 0; g_end[id] = 0;g_luc[id] = 0; 
	g_money[id] = 0; g_job[id] = 0; g_Player_RespawnTime[id] = -1;
} 


//皮肤枪
public rpg_Give_Weapon_Skin(client,String:WpnName[], SkinId)
{
	new entity = GivePlayerItem(client,  WpnName);
	new m_iItemIDHigh = GetEntProp(entity, Prop_Send, "m_iItemIDHigh");
	new m_iItemIDLow = GetEntProp(entity, Prop_Send, "m_iItemIDLow");

	SetEntProp(entity,Prop_Send,"m_iItemIDLow",2048);
	SetEntProp(entity,Prop_Send,"m_iItemIDHigh",0);

	SetEntProp(entity,Prop_Send,"m_nFallbackPaintKit", SkinId);
    
	new Handle:pack;
	CreateDataTimer(2.0, RestoreItemID, pack);
	WritePackCell(pack,entity);
	WritePackCell(pack, m_iItemIDHigh);
	WritePackCell(pack, m_iItemIDLow);
}

public Action:RestoreItemID(Handle:timer, Handle:pack)
{
	new entity;
	new m_iItemIDHigh;
	new m_iItemIDLow;
    
	ResetPack(pack);
	entity = ReadPackCell(pack);
	m_iItemIDHigh = ReadPackCell(pack);
	m_iItemIDLow = ReadPackCell(pack);
    
    
	SetEntProp(entity,Prop_Send,"m_iItemIDHigh",m_iItemIDHigh);
	SetEntProp(entity,Prop_Send,"m_iItemIDLow",m_iItemIDLow);
}  

//扒武器
public rpg_Strip_Weapon(client, slot)
{
	if(client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		new WpnEnt
		if((WpnEnt = GetPlayerWeaponSlot(client, slot)) != -1)
		{
			RemovePlayerItem(client, WpnEnt);
			AcceptEntityInput(WpnEnt, "Kill");
		}
	}
}
