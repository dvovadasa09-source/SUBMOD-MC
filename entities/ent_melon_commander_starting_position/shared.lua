ENT.PrintName = "Starting Position"
ENT.Category = "Melon Commander"
ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.Author = "toph"
ENT.Contact = "STEAM_0:1:410285675"

ENT.Spawnable = true
ENT.AdminOnly = true

ENT.AvailableNamesList = {
  "Cat", "Dog", "Sun", "Moon", "Star", "Tree", "Book", "Pen",
  "Door", "Ball", "Hand", "Foot", "Eye", "Ear", "Nose", "Heart",
  "House", "Car", "Road", "Water", "Fire", "Wind", "Earth", "Flower",
  "Fruit", "Bread", "Milk", "Coffee", "Sugar", "Salt", "Light", "Dark",
  "Day", "Night", "Time", "Week", "Month", "Year", "King", "Queen",
  "Child", "Adult", "Friend", "Family", "School", "Work", "Home", "World",
  "City", "Town", "River", "Ocean", "Mountain", "Beach", "Forest", "Garden",
  "Chair", "Table", "Spoon", "Knife", "Plate", "Cup", "Bowl", "Clock",
  "Phone", "Paper", "Music", "Song", "Dance", "Game", "Color", "Shape",
  "Sound", "Smell", "Taste", "Touch", "Happy", "Sad", "Good", "Bad",
  "Hot", "Cold", "Warm", "Cool", "Fast", "Slow", "Big", "Small",
  "High", "Low", "Soft", "Hard", "New", "Old", "Young", "Red",
  "Blue", "Green", "Yellow", "Black", "White", "Brown", "Gray", "Sweet",
  "Sour", "Bird", "Fish", "Mouse", "Horse", "Sheep", "Apple", "Orange",
  "Grape", "Bread", "Cheese", "Stone", "Glass", "Metal", "Smile", "Dream",
  "Hope", "Fear", "Truth", "Story", "Money", "Power", "Peace", "Cloud",
  "Storm", "Field", "Bridge", "Window", "Shadow", "March", "April", "Magic"
}

function ENT:SetupDataTables()
  self:NetworkVar("String", 0, "StartingPositionName")
end
