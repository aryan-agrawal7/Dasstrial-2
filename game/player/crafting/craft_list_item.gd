extends UIListItem
class_name CraftingListItem

var recipe: CraftingRecipe



func init(_recipe: CraftingRecipe, player: BasePlayer):
	recipe= _recipe
	label.text= recipe.product.get_display_name()
	update(player)
	deselect()


func update(_player: BasePlayer):
	available= false
	super(_player)
