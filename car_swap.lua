---@diagnostic disable: undefined-global, undefined-field, missing-parameter, need-check-nil, missing-return, param-type-mismatch, lowercase-global

local app_folder  = ac.getFolder(ac.FolderID.ACApps) .. '/lua/car_swap/'
local cars_folder = ac.getFolder(ac.FolderID.ContentCars)
local swap_file   = app_folder .. 'session_swap.ini'
local vecDOWN     = vec3(0, -1, 0)
local APP_ID      = 'car_swap'

local COL = {
  green     = rgbm(0.2, 0.85, 0.3, 1),
  green_dim = rgbm(0.05, 0.35, 0.1, 1),
  red       = rgbm(0.9, 0.2, 0.2, 1),
  blue      = rgbm(0.25, 0.55, 1, 1),
  blue_dim  = rgbm(0.08, 0.2, 0.45, 1),
  orange    = rgbm(1, 0.6, 0.1, 1),
  gray      = rgbm(0.45, 0.45, 0.45, 1),
  gray_dark = rgbm(0.2, 0.2, 0.2, 1),
  white     = rgbm(1, 1, 1, 1),
  yellow    = rgbm(1, 0.88, 0.1, 1),
  cm_bg     = rgbm(0.12, 0.12, 0.14, 1),
  cm_sel    = rgbm(0.22, 0.35, 0.55, 0.55),
}

local CAT_TYPES = { 'Marque', 'Tags', 'Classe', 'Pays', 'Annee', 'Auteur', 'Toutes' }

local VIEW_LIST = 1
local VIEW_GRID = 2

local settings = ac.storage({
  filterPanelH     = 40,
  carListH         = 220,
  sidebarW         = 160,
  carListW         = 240,
  previewW         = 280,
  categoryViewMode = VIEW_LIST,
  viewMode         = VIEW_LIST,
  language         = 'fr',
  openKeyCode      = ui.KeyIndex.F9,
  openKey          = 'F9',
}, 'car_swap_ui')

local TRANSLATIONS = {
  fr = {
    settings = 'Paramètres',
    opening_key = "Touche d'ouverture",
    bind_key = 'Lier une touche',
    current_key = 'Touche actuelle : ',
    language = 'Langue',
    language_fr = 'Français',
    language_en = 'English',
    vehicle_list_display = 'Affichage de la liste de voitures',
    filter_selector_display = 'Affichage du sélecteur de filtres',
    module_sizes = 'Taille des modules (pixels)',
    back_label = 'Retour',
    choose_car = 'Choisir une voiture',
    search = 'Recherche',
    category = 'Catégorie',
    values = 'Valeurs',
    search_filters = 'Rechercher',
    no_cars_found = 'Aucune voiture trouvée',
    change_car = 'Changer de voiture',
    list = 'Liste',
    grid = 'Grille',
    skin_default = 'Skin : défaut (aucun skin alternatif)',
    filter_brand = 'Marque',
    filter_tags = 'Tags',
    filter_class = 'Classe',
    filter_country = 'Pays',
    filter_year = 'Année',
    filter_author = 'Auteur',
    filter_all = 'Toutes',
    filter_loading = 'Chargement des filtres...',
    filter_none = 'Aucun élément trouvé',
    filter_hint = 'Marque, pays, classe, tag, auteur…',
    slider_categories = 'Largeur catégories',
    slider_list = 'Largeur liste',
    slider_preview = 'Largeur preview',
    slider_filters = 'Hauteur filtres',
    loading_cars = 'Chargement voitures…',
    search_tooltip = 'Nom, marque, tag, classe, pays, année ou auteur',
    online_disabled = 'Mode en ligne : fonction désactivée',
  },
  en = {
    settings = 'Settings',
    opening_key = 'Open key',
    bind_key = 'Bind a key',
    current_key = 'Current key: ',
    language = 'Language',
    language_fr = 'French',
    language_en = 'English',
    vehicle_list_display = 'Vehicle list display',
    filter_selector_display = 'Filter selector display',
    module_sizes = 'Module sizes (pixels)',
    back_label = 'Back',
    choose_car = 'Choose a car',
    search = 'Search',
    category = 'Category',
    values = 'Values',
    search_filters = 'Search',
    no_cars_found = 'No cars found',
    change_car = 'Change car',
    list = 'List',
    grid = 'Grid',
    skin_default = 'Skin: default (no alternate skin)',
    filter_brand = 'Brand',
    filter_tags = 'Tags',
    filter_class = 'Class',
    filter_country = 'Country',
    filter_year = 'Year',
    filter_author = 'Author',
    filter_all = 'All',
    filter_loading = 'Loading filters...',
    filter_none = 'No items found',
    filter_hint = 'Brand, country, class, tag, author…',
    slider_categories = 'Category width',
    slider_list = 'List width',
    slider_preview = 'Preview width',
    slider_filters = 'Filter height',
    loading_cars = 'Loading cars…',
    search_tooltip = 'Name, brand, tag, class, country, year or author',
    online_disabled = 'Online mode: feature disabled',
  },
}

local function tr(key)
  local lang = settings.language or 'fr'
  if TRANSLATIONS[lang] and TRANSLATIONS[lang][key] then
    return TRANSLATIONS[lang][key]
  end
  return TRANSLATIONS.fr[key] or key
end

local function getCatTypeLabel(typeName)
  if typeName == 'Marque' then return tr('filter_brand') end
  if typeName == 'Tags' then return tr('filter_tags') end
  if typeName == 'Classe' then return tr('filter_class') end
  if typeName == 'Pays' then return tr('filter_country') end
  if typeName == 'Annee' then return tr('filter_year') end
  if typeName == 'Auteur' then return tr('filter_author') end
  if typeName == 'Toutes' then return tr('filter_all') end
  return typeName
end

local target_car   = ''
local target_skin  = ''
local last_car     = nil
local feedback     = { msg = '', col = COL.white, timer = 0 }
local restore_done = false
local restore_wait = 0
local restore_tries = 0
local init_done    = false
local recent_cars  = {}

local cat_type     = 'Toutes'
local cat_value    = 'Toutes'
local cat_values   = { 'Toutes' }
local search_buf   = ''
local category_search_buf = ''
local skin_options = {}
local preview_cache = {}
local badge_cache   = {}
local brand_badge_cache = {}

local settings_open = false
local open_key_code = settings.openKeyCode or ui.KeyIndex.F9
local open_key = settings.openKey or 'F9'
local changeBtn = nil
local custom_key_error = ''
local bind_mode = false
local open_key_pressed = false
local close_interface = false

local keyOptions = {
  { label = 'F8', code = ui.KeyIndex.F8 },
  { label = 'F9', code = ui.KeyIndex.F9 },
  { label = 'F10', code = ui.KeyIndex.F10 },
  { label = 'F11', code = ui.KeyIndex.F11 },
  { label = 'F12', code = ui.KeyIndex.F12 },
  { label = 'Espace', code = ui.KeyIndex.Space },
  { label = 'Entrer', code = ui.KeyIndex.Enter },
  { label = 'Escape', code = ui.KeyIndex.Escape },
  { label = 'Tab', code = ui.KeyIndex.Tab },
  { label = 'Backspace', code = ui.KeyIndex.Backspace },
  { label = 'Delete', code = ui.KeyIndex.Delete },
  { label = 'Shift', code = ui.KeyIndex.LeftShift },
  { label = 'Ctrl', code = ui.KeyIndex.LeftCtrl },
  { label = 'Alt', code = ui.KeyIndex.LeftAlt },
  { label = 'Fleche', code = ui.KeyIndex.Up },
}

local function getKeyLabel(code)
  for _, opt in ipairs(keyOptions) do
    if opt.code == code then return opt.label end
  end
  return tostring(code or 'Inconnue')
end

local function resolveKeyCode(key)
  if type(key) == 'number' then return key end
  if type(key) ~= 'string' then return nil end

  local normalized = (key:gsub('^%s+', ''):gsub('%s+$', ''))
  if normalized == '' then return nil end

  local aliases = {
    f1 = ui.KeyIndex.F1,
    f2 = ui.KeyIndex.F2,
    f3 = ui.KeyIndex.F3,
    f4 = ui.KeyIndex.F4,
    f5 = ui.KeyIndex.F5,
    f6 = ui.KeyIndex.F6,
    f7 = ui.KeyIndex.F7,
    f8 = ui.KeyIndex.F8,
    f9 = ui.KeyIndex.F9,
    f10 = ui.KeyIndex.F10,
    f11 = ui.KeyIndex.F11,
    f12 = ui.KeyIndex.F12,
    espace = ui.KeyIndex.Space,
    space = ui.KeyIndex.Space,
    entrer = ui.KeyIndex.Enter,
    enter = ui.KeyIndex.Enter,
    escape = ui.KeyIndex.Escape,
    tab = ui.KeyIndex.Tab,
    backspace = ui.KeyIndex.Backspace,
    delete = ui.KeyIndex.Delete,
    shift = ui.KeyIndex.LeftShift,
    leftshift = ui.KeyIndex.LeftShift,
    rightshift = ui.KeyIndex.RightShift,
    ctrl = ui.KeyIndex.LeftCtrl,
    leftctrl = ui.KeyIndex.LeftCtrl,
    rightctrl = ui.KeyIndex.RightCtrl,
    alt = ui.KeyIndex.LeftAlt,
    leftalt = ui.KeyIndex.LeftAlt,
    rightalt = ui.KeyIndex.RightAlt,
    up = ui.KeyIndex.Up,
    down = ui.KeyIndex.Down,
    left = ui.KeyIndex.Left,
    right = ui.KeyIndex.Right,
  }

  local low = normalized:lower()
  if aliases[low] ~= nil then return aliases[low] end

  local direct = ui.KeyIndex[normalized]
  if direct ~= nil then return direct end

  local upper = normalized:upper()
  if ui.KeyIndex[upper] ~= nil then return ui.KeyIndex[upper] end

  if #normalized == 1 then
    local letter = normalized:upper()
    if ui.KeyIndex[letter] ~= nil then return ui.KeyIndex[letter] end
  end

  return nil
end

local function isKeyPressed(code)
  if type(code) ~= 'number' then return false end
  if ui and ui.isKeyPressed then
    local ok, res = pcall(ui.isKeyPressed, code)
    if ok and res then return true end
  end
  if ac and ac.isKeyPressed then
    local ok, res = pcall(ac.isKeyPressed, code)
    if ok and res then return true end
  end
  return false
end

local function detectPressedKey()
  if not ui or not ui.KeyIndex then return nil end
  local keys = {}
  for _, code in pairs(ui.KeyIndex) do
    if type(code) == 'number' and code > 0 then
      keys[#keys + 1] = code
    end
  end
  table.sort(keys)
  for _, code in ipairs(keys) do
    if isKeyPressed(code) then return code end
  end
  return nil
end

local function bindOpenButton()
  changeBtn = ac.ControlButton('car_swap/Change Car', {
    keyboard = { key = open_key_code },
  })
  changeBtn:onPressed(function()
    ac.setAppOpen(APP_ID)
  end)
  changeBtn:setAlwaysActive(true)
end

local function setOpenKey(code)
  local resolved = resolveKeyCode(code)
  if not resolved then
    bind_mode = false
    custom_key_error = 'Touche invalide : ' .. tostring(code)
    notify(custom_key_error, COL.orange)
    return false
  end

  open_key_code = resolved
  open_key = getKeyLabel(resolved)
  custom_key_error = ''
  settings.openKeyCode = resolved
  settings.openKey = open_key
  bind_mode = false
  bindOpenButton()
  notify('Touche d\'ouverture changee vers ' .. open_key, COL.green)
  return true
end

bindOpenButton()

local catalog = {
  cars        = {},
  by_type     = {},
  scan_queue  = nil,
  scan_done   = false,
  scan_total  = 0,
  scan_loaded = 0,
}

local function notify(msg, col)
  feedback.msg   = msg
  feedback.col   = col or COL.white
  feedback.timer = 3.5
end

local function addRecent(carId)
  if not carId or carId == '' then return end
  for i, c in ipairs(recent_cars) do
    if c == carId then table.remove(recent_cars, i) break end
  end
  table.insert(recent_cars, 1, carId)
  while #recent_cars > 6 do table.remove(recent_cars) end
end

local function deleteSwapFile()
  if io.deleteFile then pcall(io.deleteFile, swap_file)
  elseif io.exists(swap_file) then io.save(swap_file, '') end
end

local function writeSwap(data)
  local lines = {
    '[SWAP]',
    'PENDING=1',
    'POS_X=' .. string.format('%.4f', data.pos.x),
    'POS_Y=' .. string.format('%.4f', data.pos.y),
    'POS_Z=' .. string.format('%.4f', data.pos.z),
    'DIR_X=' .. string.format('%.4f', data.dir.x),
    'DIR_Z=' .. string.format('%.4f', data.dir.z),
    'TRACK=' .. data.track,
    'FROM_CAR=' .. data.from_car,
    'TO_CAR=' .. data.to_car,
    'SKIN=' .. (data.skin or ''),
  }
  io.save(swap_file, table.concat(lines, '\n'))
end

local function readSwap()
  if not io.exists(swap_file) then return nil end
  local ini = ac.INIConfig.load(swap_file, ac.INIFormat.Extended)
  if ini:get('SWAP', 'PENDING', '0') ~= '1' then return nil end
  return {
    pos      = vec3(ini:get('SWAP','POS_X',0), ini:get('SWAP','POS_Y',0), ini:get('SWAP','POS_Z',0)),
    dir      = vec3(ini:get('SWAP','DIR_X',0), 0, ini:get('SWAP','DIR_Z',1)),
    track    = ini:get('SWAP', 'TRACK', ''),
    from_car = ini:get('SWAP', 'FROM_CAR', ''),
    to_car   = ini:get('SWAP', 'TO_CAR', ''),
    skin     = ini:get('SWAP', 'SKIN', ''),
  }
end

local function teleportTo(pos, dir)
  local car = ac.getCar(0)
  if not car or not car.physicsAvailable then return false end
  local probe = vec3(pos.x, pos.y + 5, pos.z)
  local hit   = physics.raycastTrack(probe, vecDOWN, 30)
  local fy    = (hit ~= -1) and ((pos.y + 5) - hit + 0.15) or pos.y
  local look  = vec3(dir.x, 0, dir.z)
  if look:length() < 0.01 then look = vec3(0, 0, 1) end
  physics.setCarPosition(0, vec3(pos.x, fy, pos.z), -look)
  return true
end

local function tryRestore()
  local swap = readSwap()
  if not swap then
    restore_done = true
    return
  end
  if swap.track ~= '' and swap.track ~= ac.getTrackFullID('/') then
    deleteSwapFile()
    restore_done = true
    return
  end
  local car = ac.getCar(0)
  if not car or not car.physicsAvailable then return end
  if swap.to_car ~= '' and ac.getCarID(0) ~= swap.to_car then return end
  if teleportTo(swap.pos, swap.dir) then
    if swap.from_car ~= '' then last_car = swap.from_car end
    deleteSwapFile()
    restore_done = true
    notify('Position restauree apres changement de voiture', COL.blue)
  end
end

local function buildRestartIni(newCar, skin)
  local rc     = ac.INIConfig.raceConfig()
  local track  = rc:get('RACE', 'TRACK', ac.getTrackFullID('/'))
  local config = rc:get('RACE', 'CONFIG_TRACK', '')
  local skinVal = (skin and skin ~= '') and skin or '-'
  return string.format(
    '[RACE]\nTRACK=%s\nCONFIG_TRACK=%s\nMODEL=%s\nCARS=1\n[CAR_0]\nMODEL=%s\nSKIN=%s\n',
    track, config, newCar, newCar, skinVal
  )
end

local function doChangeCar(newCar, skin)
  local sim = ac.getSim()
  if sim.isOnlineRace then
    notify('Changement de voiture indisponible en ligne', COL.red)
    return
  end

  newCar = (newCar or ''):gsub('^%s+', ''):gsub('%s+$', '')
  if newCar == '' then
    notify('Choisis une voiture dans la liste', COL.orange)
    return
  end

  local current = ac.getCarID(0)
  if current == newCar then
    notify('Tu es deja dans cette voiture', COL.orange)
    return
  end

  skin = skin or target_skin or ''

  local car = ac.getCar(0)
  if not car or not car.physicsAvailable then
    notify('Physique indisponible', COL.red)
    return
  end

  writeSwap({
    pos      = vec3(car.position.x, car.position.y, car.position.z),
    dir      = vec3(car.look.x, 0, car.look.z),
    track    = ac.getTrackFullID('/'),
    from_car = current,
    to_car   = newCar,
    skin     = skin,
  })

  last_car = current
  addRecent(current)
  addRecent(newCar)
  target_car = newCar

  notify('Changement vers ' .. newCar .. '…', COL.yellow)
  ac.restartAssettoCorsa(buildRestartIni(newCar, skin))
end

local function swapBack()
  if last_car and last_car ~= ac.getCarID(0) then
    doChangeCar(last_car, '')
    return
  end
  notify('Aucune voiture precedente en session', COL.orange)
end

-- ── Catalogue voitures (categories CM via ui_car.json) ───────────────────────

local function yearGroup(year)
  if not year or year <= 0 then return 'Annee inconnue' end
  local decade = math.floor(year / 10) * 10
  return string.format('Annees %d', decade)
end

local function addToIndex(typeName, value, carId)
  if not value or value == '' then return end
  if not catalog.by_type[typeName] then catalog.by_type[typeName] = {} end
  local bucket = catalog.by_type[typeName]
  if not bucket[value] then bucket[value] = {} end
  table.insert(bucket[value], carId)
end

local function parseCarMeta(carId)
  local uiPath = cars_folder .. '/' .. carId .. '/ui/ui_car.json'
  if not io.fileExists(uiPath) then
    return {
      id      = carId,
      name    = ac.getCarNameByID(carId) or carId,
      brand   = 'Inconnu',
      tags    = {},
      class   = 'Autre',
      country = 'Inconnu',
      year    = 0,
      author  = 'Inconnu',
    }
  end
  local ok, data = pcall(JSON.parse, io.load(uiPath, ''))
  if not ok or type(data) ~= 'table' then return nil end

  local tags = {}
  if type(data.tags) == 'table' then
    for _, t in ipairs(data.tags) do
      if type(t) == 'string' and t ~= '' then tags[#tags + 1] = t end
    end
  end

  return {
    id      = carId,
    name    = data.name or ac.getCarNameByID(carId) or carId,
    brand   = data.brand or 'Inconnu',
    tags    = tags,
    class   = data.class or 'Autre',
    country = data.country or 'Inconnu',
    year    = tonumber(data.year) or 0,
    author  = data.author or 'Inconnu',
  }
end

local function rebuildCategoryValues()
  cat_values = { 'Toutes' }
  if cat_type == 'Toutes' then
    cat_value = 'Toutes'
    return
  end
  local bucket = catalog.by_type[cat_type]
  if bucket then
    for key in pairs(bucket) do cat_values[#cat_values + 1] = key end
    table.sort(cat_values, function(a, b)
      if a == 'Toutes' then return true end
      if b == 'Toutes' then return false end
      return a:lower() < b:lower()
    end)
  end
  local found = false
  for _, v in ipairs(cat_values) do
    if v == cat_value then found = true break end
  end
  if not found then cat_value = 'Toutes' end
end

local function getFilteredCategoryValues()
  local needle = (category_search_buf or ''):lower()
  local out = {}
  for _, value in ipairs(cat_values) do
    if value == 'Toutes' then
      out[#out + 1] = value
    elseif needle == '' or value:lower():find(needle, 1, true) then
      out[#out + 1] = value
    end
  end
  return out
end

local function indexCar(meta)
  catalog.cars[meta.id] = meta
  addToIndex('Marque', meta.brand, meta.id)
  addToIndex('Classe', meta.class, meta.id)
  addToIndex('Pays', meta.country, meta.id)
  addToIndex('Annee', yearGroup(meta.year), meta.id)
  addToIndex('Auteur', meta.author, meta.id)
  for _, tag in ipairs(meta.tags) do addToIndex('Tags', tag, meta.id) end
end

local function startCatalogScan()
  if catalog.scan_queue ~= nil then return end
  local dirs = io.scanDir(cars_folder, '*') or {}
  catalog.scan_queue = {}
  for _, name in ipairs(dirs) do
    if io.dirExists(cars_folder .. '/' .. name) then
      catalog.scan_queue[#catalog.scan_queue + 1] = name
    end
  end
  catalog.scan_total = #catalog.scan_queue
  catalog.scan_loaded = 0
  catalog.scan_done = catalog.scan_total == 0
end

local function scanCatalogStep(batch)
  if catalog.scan_done or not catalog.scan_queue then return end
  for _ = 1, batch do
    local carId = table.remove(catalog.scan_queue, 1)
    if not carId then
      catalog.scan_done = true
      rebuildCategoryValues()
      return
    end
    local meta = parseCarMeta(carId)
    if meta then indexCar(meta) end
    catalog.scan_loaded = catalog.scan_loaded + 1
    if catalog.scan_loaded % 40 == 0 then rebuildCategoryValues() end
  end
end

local function getFilteredCars()
  local out = {}
  local needle = search_buf:lower()

  local function matchesSearch(meta)
    if needle == '' then return true end
    if meta.id:lower():find(needle, 1, true) then return true end
    if meta.name:lower():find(needle, 1, true) then return true end
    if meta.brand:lower():find(needle, 1, true) then return true end
    for _, tag in ipairs(meta.tags) do
      if tag:lower():find(needle, 1, true) then return true end
    end
    return false
  end

  if cat_type == 'Toutes' or cat_value == 'Toutes' then
    for _, meta in pairs(catalog.cars) do
      if matchesSearch(meta) then out[#out + 1] = meta end
    end
  else
    local bucket = catalog.by_type[cat_type]
    local ids = bucket and bucket[cat_value] or {}
    for _, id in ipairs(ids) do
      local meta = catalog.cars[id]
      if meta and matchesSearch(meta) then out[#out + 1] = meta end
    end
  end

  table.sort(out, function(a, b)
    return a.name:lower() < b.name:lower()
  end)
  return out
end

-- ── Skins & apercus ──────────────────────────────────────────────────────────

local function loadCarSkins(carId)
  local skinsPath = cars_folder .. '/' .. carId .. '/skins'
  if not io.dirExists(skinsPath) then return {} end
  local dirs = io.scanDir(skinsPath, '*') or {}
  local out = {}
  for _, name in ipairs(dirs) do
    local skinDir = skinsPath .. '/' .. name
    if io.dirExists(skinDir) then
      local label = name
      local skinJson = skinDir .. '/ui_skin.json'
      if io.fileExists(skinJson) then
        local ok, data = pcall(JSON.parse, io.load(skinJson, ''))
        if ok and type(data) == 'table' and data.skinname and data.skinname ~= '' then
          label = data.skinname
        end
      end
      out[#out + 1] = { id = name, label = label }
    end
  end
  table.sort(out, function(a, b) return a.label:lower() < b.label:lower() end)
  return out
end

local function updateSkinOptions(carId)
  skin_options = loadCarSkins(carId)
  if #skin_options == 0 then
    target_skin = ''
    return
  end
  for _, s in ipairs(skin_options) do
    if s.id == target_skin then return end
  end
  target_skin = skin_options[1].id
end

local function findPreviewInDir(dir)
  if not io.dirExists(dir) then return nil end
  local names = { 'preview.jpg', 'preview.png', 'preview.jpeg', 'Preview.jpg', 'Preview.png' }
  for _, name in ipairs(names) do
    local p = dir .. '/' .. name
    if io.fileExists(p) then return p end
  end
  local files = io.scanDir(dir, 'preview*') or {}
  for _, f in ipairs(files) do
    local p = dir .. '/' .. f
    if io.fileExists(p) then return p end
  end
  return nil
end

local function findBrandBadge(carId)
  if not carId or carId == '' then return nil end
  if badge_cache[carId] ~= nil then return badge_cache[carId] or nil end
  local path = cars_folder .. '/' .. carId .. '/ui/badge.png'
  if io.fileExists(path) then
    badge_cache[carId] = path
    return path
  end
  badge_cache[carId] = false
  return nil
end

local function findBrandBadgeByName(brandName)
  if not brandName or brandName == '' or brandName == 'Toutes' then return nil end
  if brand_badge_cache[brandName] ~= nil then return brand_badge_cache[brandName] or nil end
  local bucket = catalog.by_type['Marque']
  local ids = bucket and bucket[brandName]
  if ids then
    for _, carId in ipairs(ids) do
      local badge = findBrandBadge(carId)
      if badge then
        brand_badge_cache[brandName] = badge
        return badge
      end
    end
  end
  brand_badge_cache[brandName] = false
  return nil
end

local function findCarPreviewOnly(carId, skinId)
  if not carId or carId == '' then return nil end
  local key = carId .. '\0' .. (skinId or '') .. '\0preview'
  if preview_cache[key] ~= nil then return preview_cache[key] or nil end

  if skinId and skinId ~= '' then
    local p = findPreviewInDir(cars_folder .. '/' .. carId .. '/skins/' .. skinId)
    if p then preview_cache[key] = p return p end
  end

  local skinsPath = cars_folder .. '/' .. carId .. '/skins'
  if io.dirExists(skinsPath) then
    local dirs = io.scanDir(skinsPath, '*') or {}
    for _, name in ipairs(dirs) do
      local skinDir = skinsPath .. '/' .. name
      if io.dirExists(skinDir) then
        local p = findPreviewInDir(skinDir)
        if p then preview_cache[key] = p return p end
      end
    end
  end

  local uiDir = cars_folder .. '/' .. carId .. '/ui'
  local p = findPreviewInDir(uiDir)
  if p then preview_cache[key] = p return p end

  p = findPreviewInDir(cars_folder .. '/' .. carId)
  if p then preview_cache[key] = p return p end

  preview_cache[key] = false
  return nil
end

local function findCarPreview(carId, skinId)
  return findCarPreviewOnly(carId, skinId) or findBrandBadge(carId)
end

local function selectCar(carId)
  if target_car == carId then return end
  target_car = carId
  updateSkinOptions(carId)
end

-- ── UI ───────────────────────────────────────────────────────────────────────

local function sliderInt(label, value, min, max, format)
  local ok, res = pcall(ui.slider, label, value, min, max, format or '%.0f')
  if ok and type(res) == 'number' then
    return math.floor(res)
  end

  local ok2, res2 = pcall(ui.dragInt, label, value, 1, min, max, format or '%.0f')
  if ok2 and type(res2) == 'number' then
    return math.floor(res2)
  end

  return math.floor(value)
end

local function beginChildNoVScroll(name, size, border)
  if ui and ui.WindowFlags then
    local flags = 0
    if ui.WindowFlags.NoScrollbar then flags = flags + ui.WindowFlags.NoScrollbar end
    -- attempt to also disable scroll with mouse to prevent wheel from moving the child
    if ui.WindowFlags.NoScrollWithMouse then flags = flags + ui.WindowFlags.NoScrollWithMouse end
    if flags ~= 0 then
      local ok = pcall(ui.beginChild, name, size, border, flags)
      if ok then return end
    end
  end
  ui.beginChild(name, size, border)
end

local function drawFilterRow(label, selected, showBrandLogo)
  local logoSize = vec2(18, 18)
  if showBrandLogo then
    local badge = findBrandBadgeByName(label)
    if badge then
      ui.image(badge, logoSize)
      ui.sameLine(logoSize.x + 6)
    end
  end
  if ui.selectable(label .. '##val_' .. label, selected) then
    cat_value = label
  end
end

local function categoryGridColumnCount(w)
  if w >= 280 then return 2 end
  return 1
end

local function drawCategoryGrid(values, availW)
  local cols = categoryGridColumnCount(availW)
  local gap = 6
  local tileW = math.floor((availW - gap * (cols - 1)) / cols)

  for i, label in ipairs(values) do
    if i > 1 and (i - 1) % cols ~= 0 then
      ui.sameLine(0, gap)
    end

    local selected = cat_value == label
    if selected then ui.pushStyleColor(ui.StyleColor.ChildBg, COL.cm_sel) end

    ui.beginChild('cat_tile_' .. label, vec2(tileW, 72), true)
    local badge = findBrandBadgeByName(label)
    if badge then
      ui.image(badge, vec2(40, 40))
      ui.sameLine(0, 8)
    end
    ui.pushStyleColor(ui.StyleColor.Text, selected and COL.white or COL.gray)
    if ui.selectable(label .. '##cat_tile_' .. label, selected) then
      cat_value = label
    end
    ui.popStyleColor()
    if ui.itemHovered() then
      ui.setTooltip(label)
    end
    ui.endChild()

    if selected then ui.popStyleColor() end
  end
end

local function gridColumnCount(w)
  if w >= 520 then return 3 end
  if w >= 340 then return 2 end
  return 1
end

local function drawCarRow(meta, selected)
  local thumb = findCarPreviewOnly(meta.id, nil) or findBrandBadge(meta.id)
  local thumbSize = vec2(40, 40)

  if thumb then
    ui.image(thumb, thumbSize)
    ui.sameLine(thumbSize.x + 8)
  end

  if ui.selectable(meta.name .. '##c' .. meta.id, selected) then
    selectCar(meta.id)
  end
  if ui.itemHovered() then
    local tagStr = #meta.tags > 0 and table.concat(meta.tags, ', ') or '-'
    ui.setTooltip(meta.id .. '\n' .. meta.brand .. ' · ' .. meta.class
      .. '\n' .. meta.country .. ' · ' .. (meta.year > 0 and tostring(meta.year) or '?')
      .. '\nTags: ' .. tagStr)
  end
end

local function drawCarGrid(filtered, availW)
  local cols = gridColumnCount(availW)
  local gap = 6
  local tileW = math.floor((availW - gap * (cols - 1)) / cols)
  local imgH = math.floor(tileW * 0.56)
  local tileH = imgH + 34

  for i, meta in ipairs(filtered) do
    if i > 1 and (i - 1) % cols ~= 0 then
      ui.sameLine(0, gap)
    end

    local selected = target_car == meta.id
    if selected then
      ui.pushStyleColor(ui.StyleColor.ChildBg, COL.cm_sel)
    end

    ui.beginChild('tile_' .. meta.id, vec2(tileW, tileH), true)
    local preview = findCarPreviewOnly(meta.id, nil) or findBrandBadge(meta.id)
    if preview then
      ui.image(preview, vec2(tileW - 12, imgH))
    else
      ui.dummy(vec2(tileW - 12, imgH))
      ui.textColored('Sans preview', COL.gray_dark)
    end

    ui.pushStyleColor(ui.StyleColor.Text, selected and COL.white or COL.gray)
    if ui.selectable(meta.name .. '##g' .. meta.id, selected) then
      selectCar(meta.id)
    end
    ui.popStyleColor()

    if ui.itemHovered() then
      ui.setTooltip(meta.id .. '\n' .. meta.brand)
    end
    ui.endChild()

    if selected then ui.popStyleColor() end
  end
end

local function drawMainPanel()
  local W = ui.windowSize().x
  local sim = ac.getSim()
  local currentId   = ac.getCarID(0) or '?'
  local currentName = ac.getCarName(0) or currentId

  if feedback.timer > 0 then
    ui.textColored(feedback.msg, feedback.col)
    ui.separator()
  end

  if not catalog.scan_done then
    local pct = catalog.scan_total > 0
      and math.floor(catalog.scan_loaded / catalog.scan_total * 100) or 0
    ui.textColored(tr('loading_cars') .. ' ' .. pct .. '%', COL.gray)
    ui.separator()
  end

  ui.pushStyleColor(ui.StyleColor.Button, COL.blue_dim)
  ui.pushStyleColor(ui.StyleColor.ButtonHovered, COL.blue)
  if ui.button(tr('settings'), vec2(110, 26)) then
    settings_open = not settings_open
  end
  ui.popStyleColor(2)
  ui.offsetCursorY(6)

  if settings_open then
    local settingsH = math.max(240, ui.windowSize().y - 80)
    ui.pushStyleColor(ui.StyleColor.ChildBg, COL.cm_bg)
    ui.beginChild('settings_window', vec2(0, settingsH), true)
    ui.popStyleColor()
    ui.textColored(tr('settings'), COL.yellow)

    ui.textColored(tr('language'), COL.white)
    local langLabel = (settings.language == 'en') and tr('language_en') or tr('language_fr')
    ui.combo('##lang_select', langLabel, ui.ComboFlags.None, function()
      if ui.selectable(tr('language_fr') .. '##lang_fr', settings.language ~= 'en') then
        settings.language = 'fr'
      end
      if ui.selectable(tr('language_en') .. '##lang_en', settings.language == 'en') then
        settings.language = 'en'
      end
    end)
    ui.offsetCursorY(6)

    ui.textColored(tr('opening_key'), COL.white)
    if custom_key_error ~= '' then
      ui.textColored(custom_key_error, COL.orange)
    end
    ui.offsetCursorY(4)
    if ui.button(bind_mode and 'En attente…' or tr('bind_key'), vec2(150, 24)) then
      bind_mode = not bind_mode
      if bind_mode then
        custom_key_error = ''
        notify('Appuie sur la touche souhaitée…', COL.yellow)
      end
    end
    if bind_mode then
      ui.textColored('Attente d\'une touche…', COL.yellow)
    end
    ui.offsetCursorY(6)
    ui.textColored(tr('current_key') .. open_key, COL.gray)
    ui.offsetCursorY(10)
    ui.separator()
    ui.offsetCursorY(6)

    ui.textColored(tr('vehicle_list_display'), COL.white)
    if ui.radioButton(tr('list') .. '##vm_list', settings.viewMode == VIEW_LIST) then
      settings.viewMode = VIEW_LIST
    end
    ui.sameLine()
    if ui.radioButton(tr('grid') .. '##vm_grid', settings.viewMode == VIEW_GRID) then
      settings.viewMode = VIEW_GRID
    end
    ui.offsetCursorY(4)

    ui.textColored(tr('filter_selector_display'), COL.white)
    if ui.radioButton(tr('list') .. '##cat_vm_list', settings.categoryViewMode == VIEW_LIST) then
      settings.categoryViewMode = VIEW_LIST
    end
    ui.sameLine()
    if ui.radioButton(tr('grid') .. '##cat_vm_grid', settings.categoryViewMode == VIEW_GRID) then
      settings.categoryViewMode = VIEW_GRID
    end
    ui.offsetCursorY(6)

    ui.textColored(tr('module_sizes'), COL.white)
    ui.offsetCursorY(4)

    settings.sidebarW = sliderInt(tr('slider_categories') .. '##sidebar_w', settings.sidebarW, 120, 720, '%.0f px')
    ui.offsetCursorY(2)
    settings.carListW = sliderInt(tr('slider_list') .. '##carlist_w', settings.carListW, 180, 720, '%.0f px')
    ui.offsetCursorY(2)
    settings.previewW = sliderInt(tr('slider_preview') .. '##preview_w', settings.previewW, 220, 720, '%.0f px')
    ui.offsetCursorY(2)
      settings.filterPanelH = sliderInt(tr('slider_filters') .. '##filter_h', settings.filterPanelH, 16, 220, '%.0f px')
    ui.offsetCursorY(10)
    if ui.button(tr('back_label'), vec2(90, 24)) then
      settings_open = false
    end
    ui.endChild()
    return
  end

  ui.textColored(tr('choose_car'), COL.yellow)
  search_buf = ui.inputText(tr('search') .. '##search', search_buf, 64)
  if ui.itemHovered() then
    ui.setTooltip(tr('search_tooltip'))
  end
  ui.offsetCursorY(0)

    local topH = math.max(16, math.min(80, settings.filterPanelH))
  local contentH = math.max(320, ui.windowSize().y - 220 - topH)
  local contentW = math.max(260, ui.windowSize().x)
  local moduleH = math.max(240, ui.windowSize().y - 220)
  local previewW = math.max(220, math.min(720, settings.previewW))

  beginChildNoVScroll('main_content', vec2(0, contentH + topH), false)
  ui.beginChild('search_panel', vec2(0, topH), false)
  ui.endChild()


  local gap = 8
  local sidebarW = math.max(120, math.min(720, settings.sidebarW))
  local carListW = math.max(180, math.min(720, settings.carListW))
  local availableW = math.max(260, contentW - gap * 2)
  local previewW = math.max(220, math.min(720, settings.previewW))
  local remainingW = math.max(220, availableW - sidebarW - carListW)
  if previewW > remainingW then previewW = remainingW end

  ui.beginChild('module_row', vec2(0, moduleH), false)
  ui.beginChild('cat_sidebar', vec2(sidebarW, moduleH), false)
  ui.textColored(tr('category'), COL.gray)
  for _, t in ipairs(CAT_TYPES) do
    local label = getCatTypeLabel(t)
    local sel = cat_type == t
    if ui.selectable(label .. '##cat_' .. t, sel) then
      cat_type = t
      cat_value = 'Toutes'
      rebuildCategoryValues()
    end
  end

  rebuildCategoryValues()

  ui.separator()
  ui.textColored(tr('values'), COL.gray)
  category_search_buf = ui.inputText(tr('search_filters') .. '##cat_filter', category_search_buf, 64)
  if ui.itemHovered() then
    ui.setTooltip(tr('filter_hint'))
  end
  local visible_values = getFilteredCategoryValues()
  if #cat_values == 0 then
    ui.textColored(tr('filter_loading'), COL.gray)
  elseif #visible_values == 0 then
    ui.textColored(tr('filter_none'), COL.gray)
  elseif settings.categoryViewMode == VIEW_GRID then
    drawCategoryGrid(visible_values, ui.availableSpaceX())
  else
    for _, value in ipairs(visible_values) do
      drawFilterRow(value, cat_value == value, cat_type == 'Marque')
    end
  end
  ui.endChild()

  ui.sameLine(0, gap)

  ui.beginChild('car_list', vec2(carListW, moduleH), false)
  local filtered = getFilteredCars()
  if settings.viewMode == VIEW_GRID then
    drawCarGrid(filtered, ui.availableSpaceX())
  else
    for _, meta in ipairs(filtered) do
      drawCarRow(meta, target_car == meta.id)
    end
  end
  if #filtered == 0 and catalog.scan_done then
    ui.textColored(tr('no_cars_found'), COL.gray_dark)
  end
  ui.endChild()

  ui.sameLine(0, gap)

  ui.beginChild('preview_panel', vec2(previewW, moduleH), false)
  if target_car ~= '' then
    local meta = catalog.cars[target_car]
    local selName = meta and meta.name or target_car
    ui.textColored('Selection : ' .. selName, COL.white)

    local preview = findCarPreview(target_car, target_skin)
    if preview then
      ui.offsetCursorY(4)
      ui.image(preview, vec2(ui.availableSpaceX(), math.max(140, ui.availableSpaceX() * 0.56)))
    end

    if #skin_options > 0 then
      ui.offsetCursorY(4)
      ui.textColored('Skin', COL.yellow)
      local skinLabel = target_skin
      for _, s in ipairs(skin_options) do
        if s.id == target_skin then skinLabel = s.label break end
      end
      ui.combo('##skin_pick', skinLabel, ui.ComboFlags.None, function()
        for _, s in ipairs(skin_options) do
          if ui.selectable(s.label .. '##' .. s.id, target_skin == s.id) then
            target_skin = s.id
          end
        end
      end)
    else
      ui.textColored(tr('skin_default'), COL.gray)
      target_skin = ''
    end
  end

  ui.offsetCursorY(6)

  if #recent_cars > 0 then
    for _, c in ipairs(recent_cars) do
      if c ~= currentId then
        if ui.selectable(c .. '##r' .. c, target_car == c) then selectCar(c) end
      end
    end
    ui.offsetCursorY(4)
  end

  ui.endChild()
  ui.endChild()
  ui.endChild()

  local footerY = math.max(20, ui.windowSize().y - 44)
  ui.setCursor(vec2(0, footerY))
  ui.pushStyleColor(ui.StyleColor.Button, COL.green_dim)
  ui.pushStyleColor(ui.StyleColor.ButtonHovered, COL.green)
  if ui.button(tr('change_car'), vec2(ui.availableSpaceX(), 30)) then
    doChangeCar(target_car, target_skin)
  end
  ui.popStyleColor(2)

  if sim.isOnlineRace then
    ui.setCursor(vec2(0, footerY + 36))
    ui.textColored(tr('online_disabled'), COL.red)
  end
end

function script.update(dt)
  if not init_done then
    init_done = true
    ac.onRelease(function()
      if not io.exists(swap_file) then return end
      local ini = ac.INIConfig.load(swap_file, ac.INIFormat.Extended)
      if ini:get('SWAP', 'PENDING', '0') == '1' then return end
      deleteSwapFile()
    end)
    bindOpenButton()
    addRecent(ac.getCarID(0))
    startCatalogScan()
  end

  if bind_mode then
    local code = detectPressedKey()
    if code then
      setOpenKey(code)
    end
  end

  if not bind_mode then
    local pressed = isKeyPressed(open_key_code)
    if pressed and not open_key_pressed then
      ac.setAppOpen(APP_ID)
    end
    open_key_pressed = pressed
  end

  scanCatalogStep(12)

  if not restore_done then
    restore_wait = restore_wait + dt
    if restore_wait >= 0.5 then
      tryRestore()
      if not restore_done then
        restore_tries = restore_tries + 1
        if restore_tries > 120 then
          restore_done = true
          deleteSwapFile()
          notify('Echec restauration de position', COL.red)
        end
      end
    end
  end
end

function script.windowMain(dt)
  if feedback.timer > 0 then feedback.timer = feedback.timer - dt end
  drawMainPanel()
end
