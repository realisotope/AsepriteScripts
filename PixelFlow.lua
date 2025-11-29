-- =========================================================
-- PixelFlow, by Isotope. 
-- =========================================================

local version = "1.0.2"

local fs = app.fs
local separator = fs.pathSeparator
local scriptPath = fs.userConfigPath .. separator .. "scripts"
local storageFile = scriptPath .. separator .. "PixelFlow_Data.json"

local projects = {}

local showUI

local function saveProjectData()
    local file = io.open(storageFile, "w")
    if file then
        file:write(json.encode(projects))
        file:close()
    end
end

local function saveState(name, silent)
    if name == nil or name == "" then app.alert("Name cannot be empty.") return false end
    local filePaths = {}
    for _, sprite in ipairs(app.sprites) do
        if sprite.filename ~= "" then table.insert(filePaths, sprite.filename) end
    end
    if #filePaths == 0 then app.alert("No saved files are currently open.") return false end
    projects[name] = filePaths
    saveProjectData()
    return true
end

local function openProjectFiles(name)
    local paths = projects[name]
    if not paths then return end
    local missing = 0
    for _, path in ipairs(paths) do
        if fs.isFile(path) then app.open(path) else missing = missing + 1 end
    end
    if missing > 0 then app.alert("Loaded with " .. missing .. " missing files.") end
end

local function launchNewWindow(name)
    local paths = projects[name]
    if not paths then return end
    local exe = getAsepriteExe()
    local cmd = exe
    for _, path in ipairs(paths) do cmd = cmd .. ' "' .. path .. '"' end
    if os.getenv("OS") == "Windows_NT" then
        os.execute('start "" ' .. cmd)
    else
        os.execute(cmd .. " &") 
    end
end

local function getFileSizeStr(path)
    local file = io.open(path, "rb")
    if not file then return "Missing" end
    local size = file:seek("end")
    file:close()
    
    if size < 1024 then return size .. " B" end
    if size < 1048576 then return string.format("%.1f KB", size / 1024) end
    return string.format("%.1f MB", size / 1048576)
end

local function getExtension(path)
    return path:match("^.+(%..+)$") or ""
end

local function getFileName(path)
    return path:match("[^" .. separator .. "]+$")
end

local function getAsepriteExe()
    local path = fs.appPath
    if fs.isFile(path .. separator .. "Aseprite.exe") then
        return '"' .. path .. separator .. "Aseprite.exe" .. '"'
    elseif fs.isFile(path .. separator .. "aseprite") then
        return '"' .. path .. separator .. "aseprite" .. '"'
    else
        return "aseprite"
    end
end

local function loadProjectData()
    if fs.isFile(storageFile) then
        local file = io.open(storageFile, "r")
        if file then
            local content = file:read("*all")
            file:close()
            if content and content ~= "" then
                local status, result = pcall(function() return json.decode(content) end)
                if status and result then projects = result else projects = {} end
            end
        end
    else
        projects = {}
    end
end

local function getProjectNames()
    local names = {}
    for name, _ in pairs(projects) do table.insert(names, name) end
    table.sort(names)
    return names
end

local function getFileCount(name)
    if projects[name] then return #projects[name] end
    return 0
end

-- =========================================================
-- SUB-UI: FILE DETAILS
-- =========================================================

local function showDetailsUI(projName)
    local d = Dialog("Files: " .. projName)
    local paths = projects[projName]
    
    if not paths or #paths == 0 then
        d:label{ text="No files in this project." }
        d:button{ text="Close", onclick=function() d:close() end }
        d:show()
        return
    end

    for i, path in ipairs(paths) do
        local fname = getFileName(path)
        local fsize = getFileSizeStr(path)
        
        d:separator{ text=fname .. "  (" .. fsize .. ")" }
        d:label{ text="Path: " .. path }
        d:button{
            text="Remove File",
            onclick=function()
                table.remove(projects[projName], i)
                saveProjectData()
                d:close()
                showDetailsUI(projName)
                if showUI then showUI() end
            end
        }
        d:button{
            text="Open Path",
            onclick=function()
        local dir = fs.filePath(path)
        if not fs.isDirectory(dir) then
            return
        end

        local normalizedDir = fs.normalizePath(dir)
        local quotedDir = '"' .. normalizedDir .. '"'

        if os.getenv("OS") == "Windows_NT" then
            os.execute("explorer " .. quotedDir)
        elseif package.config:sub(1,1) == "/" then
            -- macOS or Linux Path
            local openCmd = io.popen("uname"):read("*l") == "Darwin" and "open" or "xdg-open"
            os.execute(openCmd .. " " .. quotedDir)
        end
    end
}
    end

    d:separator()
    d:button{ text="Close List", onclick=function() d:close() end }
    
    d:show{ wait=false }
end

-- =========================================================
-- MAIN UI
-- =========================================================

local dlg 
local isMinimized = false

showUI = function()
    loadProjectData()
    local names = getProjectNames()
    local selectedProject = names[1] or ""
    
    if dlg then 
        if dlg.data.proj_list and projects[dlg.data.proj_list] then
            selectedProject = dlg.data.proj_list
        end
        dlg:close() 
    end

    dlg = Dialog("PixelFlow v" .. version .. " | realisotope")
    
    -- Helper function to toggle minimize/maximize
    local function toggleMinimize()
        isMinimized = not isMinimized
        
        -- Hide/show controls
        local hideIds = {"btn_new_win", "btn_append", "btn_show_details", "btn_rename", 
                        "btn_del", "new_name", "btn_save_new", "btn_close_all", 
                        "sep_workflow"}
        
        for _, id in ipairs(hideIds) do
            dlg:modify{id=id, visible=not isMinimized}
        end
        
        -- Update button visibility
        dlg:modify{id="minimize_btn", visible=not isMinimized}
        dlg:modify{id="maximize_btn", visible=isMinimized}
        dlg:modify{id="sep_bottom", visible=not isMinimized}
    end

    -- MAIN ACTIONS
    dlg:combobox{
        id="proj_list",
        label="Workflow:",
        option=selectedProject,
        options=names,
        onchange=function()
            selectedProject = dlg.data.proj_list
            dlg:modify{ id="info_lbl", text=getFileCount(selectedProject).." Files" }
        end
    }
    dlg:newrow()
    dlg:button{
        id="btn_swap",
        text="Swap to",
        onclick=function() 
            if selectedProject ~= "" then 
                app.command.CloseAllFiles()
                openProjectFiles(selectedProject) 
            end 
        end
    }
    dlg:button{
        id="btn_update",
        text="Update",
        onclick=function()
            if selectedProject ~= "" then
                local c = app.alert{title="Update", text="Overwrite '"..selectedProject.."'?", buttons={"Yes","No"}}
                if c == 1 then saveState(selectedProject, true) showUI() end
            end
        end
    }
    dlg:button{
        id="maximize_btn",
        text="Maximize",
        visible=false,
        onclick=function()
            toggleMinimize()
        end
    }
    dlg:newrow()
    dlg:button{
        id="btn_new_win",
        text="Window (+)",
        onclick=function() if selectedProject ~= "" then launchNewWindow(selectedProject) end end
    }
    dlg:button{
        id="btn_append",
        text="Append to",
        onclick=function() if selectedProject ~= "" then openProjectFiles(selectedProject) end end
    }
    dlg:newrow()
    dlg:button{
        id="btn_show_details",
        text=getFileCount(selectedProject).." Files - Show Details",
        onclick=function() if selectedProject ~= "" then showDetailsUI(selectedProject) end end
    }

    -- WORKFLOW ACTIONS
    dlg:separator{ id="sep_workflow", text="Workflow Actions" }
    dlg:button{
        id="btn_rename",
        text="Rename",
        onclick=function()
            if selectedProject ~= "" then
                local d2 = Dialog("Rename")
                d2:entry{ id="new", text=selectedProject }
                d2:button{ text="OK", onclick=function()
                    local nn = d2.data.new
                    if nn ~= "" and not projects[nn] then
                        projects[nn] = projects[selectedProject]
                        projects[selectedProject] = nil
                        saveProjectData()
                        d2:close()
                        showUI()
                    end
                end}
                d2:show()
            end
        end
    }
    dlg:button{
        id="btn_del",
        text="Delete",
        onclick=function()
            if selectedProject ~= "" then
                local c = app.alert{title="Delete", text="Delete '"..selectedProject.."'?", buttons={"Yes","No"}}
                if c == 1 then projects[selectedProject] = nil saveProjectData() showUI() end
            end
        end
    }
    dlg:entry{ id="new_name", label="Name:" }
    dlg:button{
        id="btn_save_new",
        text="Save New Workflow",
        onclick=function()
            local nn = dlg.data.new_name
            if projects[nn] then app.alert("Name exists.")
            else if saveState(nn, false) then showUI() end end
        end
    }

    dlg:separator{ id="sep_bottom" }
    dlg:button{
        id="btn_close_all",
        text="Close All Tabs",
        onclick=function() app.command.CloseAllFiles() end
    }
    dlg:button{
        id="minimize_btn",
        text="Minimize",
        visible=true,
        onclick=function()
            toggleMinimize()
        end
    }
    
    dlg:show{ wait=false }
end

showUI()