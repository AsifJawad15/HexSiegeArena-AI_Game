class_name GameTypes
extends RefCounted

enum CellType {
	EMPTY,
	CENTER,
	WALL,
	BLOCK,
	ARMOR_BLOCK,
	POWER_BLOCK,
	POWER_ATTACK,
	POWER_SHIELD,
	POWER_BONUS_MOVE,
}

enum TankType {
	QTANK,
	KTANK,
}

enum ActionType {
	MOVE,
	ATTACK,
	PASS,
}

enum BuffType {
	NONE,
	ATTACK_MULTIPLIER,
	SHIELD_BUFFER,
	BONUS_MOVE,
}

enum ControllerType {
	HUMAN,
	MINIMAX,
	MCTS,
}
