-- By PrikolMen#3372
module( "workshop_extractor", package.seeall )

local white = color_white
local orange = Color( 250, 150, 20 )

function Message( ... )
    chat.AddText( orange, "[SWD] ", white, ... )
end

function AddonInfo( data )

    if (SChat ~= nil) then
        chat.AddText( data.previewurl )
    end

    local stars = ""
    local start_count = math.Round( data.score * 5 )
    for i = 1, start_count do
        stars = stars .. "★"
    end

    for i = 1, 5 - start_count do
        stars = stars .. "☆"
    end

    chat.AddText( Color( Lerp( data.score, 255, 0 ), Lerp( data.score, 0, 255 ), 0 ), "[", stars, "] ", orange, data.title )

    chat.AddText( orange, "Updated: ", white, os.date( "%d.%m.%Y in %H:%M", data.updated ) )
    chat.AddText( orange, "Created: ", white, os.date( "%d.%m.%Y in %H:%M", data.created ) )

    chat.AddText( orange, "Creator: ", white, data.ownername )
    chat.AddText( orange, "Tags: ", white, string.Replace( data.tags, ",", ", " ) )
    chat.AddText( orange, "Size: ", white, FormatSizeToMB( data.size ) )

end

function Func( ... )
    local ok, err = pcall( ... )
    if (ok) then return end
    Message( "Error: " .. err )
end

function FormatWSID( wsid )
    if isstring( wsid ) then
        return wsid:match( "https?://steamcommunity%.com/sharedfiles/filedetails/%?.*id=(%d+).*" ) or wsid
    end

    return wsid
end

function FormatSizeToMB( number )
    return math.Round( number / 1024 / 1024, 3 ) .. " MB"
end

do

    local allowed_extensions = {
        ["txt"] = true,
        ["dat"] = true,
        ["json"] = true,
        ["xml"] = true,
        ["csv"] = true,
        ["jpg"] = true,
        ["jpeg"] = true,
        ["png"] = true,
        ["vtf"] = true,
        ["vmt"] = true,
        ["mp3"] = true,
        ["wav"] = true,
        ["ogg"] = true
    }

    function FormatFilePath( file_path )
        if (allowed_extensions[ string.GetExtensionFromFilename( file_path ) ] == nil) then
            return file_path .. ".dat"
        end

        return file_path
    end

end

do

    local true_vars = {
        ["1"] = true,
        ["true"] = true,
        ["yes"] = true,
        ["y"] = true,
        ["да"] = true,
        ["д"] = true,
        ["ok"] = true
    }

    function IsYes( any )
        return true_vars[ any ] ~= nil
    end

end

function Save( save_path, binary_data )
    local file_class = file.Open( FormatFilePath( save_path ), "wb", "DATA" )
    if (file_class ~= nil) then
        file_class:Write( binary_data )
        file_class:Close()
        return true
    end

    return false
end

function SaveFileClass( save_path, file_class, file_size )
    local binary_data = file_class:Read( file_size )
    if (binary_data ~= nil) then
        return Save( save_path, binary_data )
    end

    return false
end

function Info( wsid, callback )
    if isstring( wsid ) then
        steamworks.FileInfo(wsid, function( data )
            Func( callback, data )
        end)

        return
    end

    Message( "Workshop id have error, please check it!" )
end

function SaveInfo( wsid, save_path )
    Info( wsid, function( data )
        Save( save_path .. "/" .. "addon.json", util.TableToJSON( data, true ) )
    end)
end

IsMounted = steamworks.ShouldMountAddon

function Mount( file_path )
    Message( "GMA Mounted: " .. file_path )
    return game.MountGMA( file_path )
end

function Download( wsid, callback )
    steamworks.DownloadUGC(wsid, function( download_path, file_class )
        local file_size = file_class:Size()
        Message( "Downloaded file: '" .. string.GetFileFromFilename( download_path ) .. "' Size: " .. FormatSizeToMB( file_size ) )
        Func( callback, download_path, file_class, file_size )
    end)
end

function CreateFolder( folder_path )
    if file.IsDir( folder_path, "DATA" ) then
        return folder_path
    end

    file.CreateDir( folder_path )
    return folder_path
end

local save_folder = CreateFolder( CreateConVar( "workshop_download_folder", "workshop_downloader", FCVAR_ARCHIVE, " - folder for downloaded adddons from workshop." ):GetString() )
cvars.AddChangeCallback("workshop_download_folder", function( name, old, new )
    save_folder = CreateFolder( new )
end, addon_name)

function SimpleDownload( wsid, dont_unpack )
    if isstring( wsid ) then
        RunConsoleCommand( "workshop_info", wsid )

        Download( wsid, function( download_path, downloaded_file, file_size )

            if (dont_unpack) then
                if SaveFileClass( save_folder .. "/" .. wsid .. ".gma", downloaded_file, file_size ) then
                    Message( "Successfully saved! (data/" .. save_folder .. "/" .. wsid .. ".gma)" )
                    return
                end

                Message( wsid .. ".gma saving failed!" )

                return
            end

            local ok, files = Mount( download_path )
            if (ok) then

                local save_path = CreateFolder( save_folder .. "/" ..  wsid )
                for num, file_path in ipairs( files ) do
                    local file_class = file.Open( file_path, "rb", "GAME" )
                    if (file_class ~= nil) then
                        CreateFolder( save_path .. "/" .. string.GetPathFromFilename( file_path ) )
                        SaveFileClass( save_path .. "/" ..  file_path, file_class )
                    end
                end

                SaveInfo( wsid, save_path )
                Message( wsid .. " successfully saved! (data/" .. save_folder .. "/" .. wsid .. "/)" )

                return
            end

            Message( wsid .. " saving failed!" )
        end)

        return
    end

    Message( "Workshop id have error, please check it!" )
end

concommand.Add("workshop_download", function( ply, cmd, args )
    SimpleDownload( FormatWSID( args[1] ), IsYes( args[2] and args[2]:lower() or nil ) )
end)

function FolderDelete( folder )
    local files, folders = file.Find( folder .. "/*", "DATA" )

    local size = 0
    for num, fl in ipairs( files ) do
        local path = folder .. "/" .. fl
        size = size + file.Size( path, "DATA" )
        file.Delete( path )
    end

    for num, fol in ipairs( folders ) do
        size = size + FolderDelete( folder .. "/" .. fol )
    end

    file.Delete( folder )
    return size
end

concommand.Add("workshop_download_clear", function()

    local files, folders = file.Find( save_folder .. "/*", "DATA" )

    if (#folders > 0) then Message( "Cleaning folders..." ) end
    for num, fol in ipairs( folders ) do
        Message( fol .. " [" .. FormatSizeToMB( FolderDelete( save_folder .. "/" .. fol ) ) .. "] was deleted!" )
    end

    if (#files > 0) then Message( "Cleaning files..." ) end
    for num, fl in ipairs( files ) do
        local full_path = save_folder .. "/" .. fl
        local size = file.Size( full_path, "DATA" )
        file.Delete( full_path )
        Message( fl .. " [" .. FormatSizeToMB( size ) .. "] was deleted!" )
    end

end)

concommand.Add("workshop_downloaded", function()
    local files, folders = file.Find( save_folder .. "/*", "DATA" )
    Message( "Downloaded: " .. util.TableToJSON({
        ["Folders"] = folders,
        ["Files"] = files
    }, true ) )
end)

concommand.Add("workshop_info", function( ply, cmd, args )
    Info( FormatWSID( args[1] ), AddonInfo )
end)
