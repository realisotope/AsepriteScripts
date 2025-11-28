-- Split Preview for Hue/Saturation/Brightness Adjustments

-- Helper function to apply contrast adjustment
function applyContrast(value, contrast)
    -- Contrast adjustment formula: ((value/255 - 0.5) * contrast + 0.5) * 255
    local normalized = value / 255.0
    local adjusted = ((normalized - 0.5) * contrast + 0.5)
    return math.max(0, math.min(255, adjusted * 255))
end

-- Helper function to apply HSB adjustments to a color
function applyHSBAdjustments(pixelValue, colorMode, hueShift, satShift, lightShift, brightnessShift, contrastFactor, useHSL, alphaShift)
    if pixelValue == 0 then
        return pixelValue
    end
    
    local pc = app.pixelColor
    
    if colorMode == ColorMode.RGB then
        -- Extract RGBA components
        local r = pc.rgbaR(pixelValue)
        local g = pc.rgbaG(pixelValue)
        local b = pc.rgbaB(pixelValue)
        local a = pc.rgbaA(pixelValue)
        
        if a == 0 and alphaShift == 0 then
            return pixelValue
        end
        
        -- Apply brightness/contrast first (on RGB values)
        if brightnessShift ~= 0 or contrastFactor ~= 1 then
            -- Apply brightness
            if brightnessShift ~= 0 then
                r = math.max(0, math.min(255, r + brightnessShift))
                g = math.max(0, math.min(255, g + brightnessShift))
                b = math.max(0, math.min(255, b + brightnessShift))
            end
            
            -- Apply contrast
            if contrastFactor ~= 1 then
                r = applyContrast(r, contrastFactor)
                g = applyContrast(g, contrastFactor)
                b = applyContrast(b, contrastFactor)
            end
        end
        
        -- Convert to Color object to access HSV/HSL
        local color = Color{ r=r, g=g, b=b, a=a }
        
        if useHSL then
            -- Use HSL mode
            local h = color.hslHue
            local s = color.hslSaturation
            local l = color.hslLightness
            
            -- Apply adjustments
            h = (h + hueShift) % 360
            s = math.max(0, math.min(1, s + satShift / 100))
            l = math.max(0, math.min(1, l + lightShift / 100))
            
            -- Create new color with adjusted values
            color = Color{ hue=h, saturation=s, lightness=l, alpha=a }
        else
            -- Use HSV mode
            local h = color.hsvHue
            local s = color.hsvSaturation
            local v = color.hsvValue
            
            -- Apply adjustments
            h = (h + hueShift) % 360
            s = math.max(0, math.min(1, s + satShift / 100))
            v = math.max(0, math.min(1, v + lightShift / 100))
            
            -- Create new color with adjusted values
            color = Color{ h=h, s=s, v=v, a=a }
        end
        
        -- Apply alpha adjustment
        if alphaShift ~= 0 then
            local newAlpha = math.max(0, math.min(255, a + alphaShift))
            r = pc.rgbaR(color.rgbaPixel)
            g = pc.rgbaG(color.rgbaPixel)
            b = pc.rgbaB(color.rgbaPixel)
            return pc.rgba(r, g, b, newAlpha)
        end
        
        return color.rgbaPixel
        
    elseif colorMode == ColorMode.GRAYSCALE then
        local gray = pc.grayaV(pixelValue)
        local alpha = pc.grayaA(pixelValue)
        
        if alpha == 0 and alphaShift == 0 then
            return pixelValue
        end
        
        -- Apply brightness
        if brightnessShift ~= 0 then
            gray = math.max(0, math.min(255, gray + brightnessShift))
        end
        
        -- Apply contrast
        if contrastFactor ~= 1 then
            gray = applyContrast(gray, contrastFactor)
        end
        
        -- Apply lightness adjustment
        if lightShift ~= 0 then
            gray = math.max(0, math.min(255, gray + (lightShift * 2.55)))
        end
        
        -- Apply alpha adjustment
        if alphaShift ~= 0 then
            alpha = math.max(0, math.min(255, alpha + alphaShift))
        end
        
        return pc.graya(gray, alpha)
    else
        -- For indexed mode, return unchanged
        return pixelValue
    end
end

-- Function to create a split preview image
function createSplitPreview(sourceImage, splitPosition, params, colorMode)
    local previewImage = Image(sourceImage.spec)
    
    -- Copy and process the image
    for it in sourceImage:pixels() do
        local x = it.x
        local y = it.y
        local pixelValue = it()
        
        if x < splitPosition then
            -- Left side: original
            previewImage:drawPixel(x, y, pixelValue)
        else
            -- Right side: adjusted
            local adjustedPixel = applyHSBAdjustments(
                pixelValue, colorMode, 
                params.hueShift, params.satShift, params.lightShift,
                params.brightnessShift, params.contrastFactor, params.useHSL, params.alphaShift
            )
            previewImage:drawPixel(x, y, adjustedPixel)
        end
    end
    
    return previewImage
end

-- Function to apply adjustments to the entire image
function applyAdjustmentsToImage(image, params, colorMode)
    local newImage = Image(image.spec)
    
    for it in image:pixels() do
        local pixelValue = it()
        local adjustedPixel = applyHSBAdjustments(
            pixelValue, colorMode,
            params.hueShift, params.satShift, params.lightShift,
            params.brightnessShift, params.contrastFactor, params.useHSL, params.alphaShift
        )
        newImage:drawPixel(it.x, it.y, adjustedPixel)
    end
    
    return newImage
end

-- Main function
function main()
    local sprite = app.sprite
    if not sprite then
        app.alert("No active sprite. Please open or create a sprite first.")
        return
    end
    
    local cel = app.cel
    if not cel then
        app.alert("No active cel. Please select a layer with content.")
        return
    end
    
    local sourceImage = cel.image:clone()
    local colorMode = sprite.colorMode
    
    -- Check if indexed mode
    if colorMode == ColorMode.INDEXED then
        app.alert("Split Preview doesn't support indexed color mode.\nPlease convert to RGB or Grayscale mode first.")
        return
    end
    
    -- Initial values
    local params = {
        hueShift = 0,
        satShift = 0,
        lightShift = 0,
        brightnessShift = 0,
        contrastFactor = 1.0,
        alphaShift = 0,
        useHSL = false
    }
    local splitPosition = math.floor(sourceImage.width / 2)
    local isMinimized = false
    
    -- Create dialog first
    local dlg = Dialog("Split Prev - Adjustments")
    
    -- Helper function to update preview
    local function updatePreview()
        -- Check if preview is enabled
        if dlg and dlg.data and (dlg.data.preview == false or dlg.data.preview_bc == false) then
            return
        end
        local preview = createSplitPreview(sourceImage, splitPosition, params, colorMode)
        cel.image = preview
        app.refresh()
    end
    
    -- Helper function to update slider values in dialog
    local function updateSliderValue(id, value)
        dlg:modify{id=id, value=value}
    end
    
    -- Helper function to toggle minimize/maximize
    local function toggleMinimize()
        isMinimized = not isMinimized
        
        -- Hide/show all controls
        local controlIds = {"useHSL", "hsv_btn", "hsl_btn", "hsv_plus", "hsl_plus", 
                           "hsv_minus", "hsl_minus", "hue", "saturation", "lightness", 
                           "alpha", "r_btn", "g_btn", "b_btn", "a_btn", "preview",
                           "brightness", "contrast", "preview_bc", "split"}
        
        for _, id in ipairs(controlIds) do
            dlg:modify{id=id, visible=not isMinimized}
        end
        
        -- Update button visibility
        dlg:modify{id="minimize_btn", visible=not isMinimized}
        dlg:modify{id="maximize_btn", visible=isMinimized}
        dlg:modify{id="apply", visible=not isMinimized}
        dlg:modify{id="reset", visible=not isMinimized}
        dlg:modify{id="cancel", visible=not isMinimized}
    end
    
    -- HSV/HSL Mode Toggle
    dlg:check{
        id="useHSL",
        text="Use HSL (instead of HSV)",
        selected=false,
        onclick=function()
            params.useHSL = dlg.data.useHSL
            updatePreview()
        end
    }
    
    dlg:newrow()
    
    dlg:button{
        id="hsv_btn",
        text="HSV",
        onclick=function()
            dlg:modify{id="useHSL", selected=false}
            params.useHSL = false
            updatePreview()
        end
    }
    
    dlg:button{
        id="hsl_btn",
        text="HSL",
        onclick=function()
            dlg:modify{id="useHSL", selected=true}
            params.useHSL = true
            updatePreview()
        end
    }
        
    -- HSV+/- buttons
    dlg:button{
        id="hsv_plus",
        text="HSV+",
        onclick=function()
            params.hueShift = math.min(180, params.hueShift + 10)
            params.satShift = math.min(100, params.satShift + 10)
            params.lightShift = math.min(100, params.lightShift + 10)
            updateSliderValue("hue", params.hueShift)
            updateSliderValue("saturation", params.satShift)
            updateSliderValue("lightness", params.lightShift)
            updatePreview()
        end
    }
    
    dlg:button{
        id="hsl_plus",
        text="HSL+",
        onclick=function()
            params.hueShift = math.min(180, params.hueShift + 10)
            params.satShift = math.min(100, params.satShift + 10)
            params.lightShift = math.min(100, params.lightShift + 10)
            updateSliderValue("hue", params.hueShift)
            updateSliderValue("saturation", params.satShift)
            updateSliderValue("lightness", params.lightShift)
            updatePreview()
        end
    }
    
    dlg:newrow()
    
    dlg:button{
        id="hsv_minus",
        text="HSV-",
        onclick=function()
            params.hueShift = math.max(-180, params.hueShift - 10)
            params.satShift = math.max(-100, params.satShift - 10)
            params.lightShift = math.max(-100, params.lightShift - 10)
            updateSliderValue("hue", params.hueShift)
            updateSliderValue("saturation", params.satShift)
            updateSliderValue("lightness", params.lightShift)
            updatePreview()
        end
    }
    
    dlg:button{
        id="hsl_minus",
        text="HSL-",
        onclick=function()
            params.hueShift = math.max(-180, params.hueShift - 10)
            params.satShift = math.max(-100, params.satShift - 10)
            params.lightShift = math.max(-100, params.lightShift - 10)
            updateSliderValue("hue", params.hueShift)
            updateSliderValue("saturation", params.satShift)
            updateSliderValue("lightness", params.lightShift)
            updatePreview()
        end
    }
    
    dlg:newrow()
    
    dlg:slider{
        id="hue",
        label="H (Hue):",
        min=-180,
        max=180,
        value=0,
        onchange=function()
            params.hueShift = dlg.data.hue
            updatePreview()
        end
    }
    
    dlg:slider{
        id="saturation",
        label="S (Saturation):",
        min=-100,
        max=100,
        value=0,
        onchange=function()
            params.satShift = dlg.data.saturation
            updatePreview()
        end
    }
    
    dlg:slider{
        id="lightness",
        label="L/V (Light/Value):",
        min=-100,
        max=100,
        value=0,
        onchange=function()
            params.lightShift = dlg.data.lightness
            updatePreview()
        end
    }
    
    dlg:slider{
        id="alpha",
        label="A (Alpha):",
        min=-255,
        max=255,
        value=0,
        onchange=function()
            params.alphaShift = dlg.data.alpha
            updatePreview()
        end
    }
    
    dlg:newrow()
    
    -- RGBA channel buttons
    dlg:button{
        id="r_btn",
        text="R",
        onclick=function()
            -- Toggle Red channel (set H=0, S=100, L=50 for pure red)
            if params.hueShift == 0 and params.satShift == 100 then
                params.hueShift = 0
                params.satShift = 0
                params.lightShift = 0
            else
                params.hueShift = 0
                params.satShift = 100
                params.lightShift = 0
            end
            updateSliderValue("hue", params.hueShift)
            updateSliderValue("saturation", params.satShift)
            updateSliderValue("lightness", params.lightShift)
            updatePreview()
        end
    }
    
    dlg:button{
        id="g_btn",
        text="G",
        onclick=function()
            -- Toggle Green channel (H=120)
            if params.hueShift == 120 and params.satShift == 100 then
                params.hueShift = 0
                params.satShift = 0
                params.lightShift = 0
            else
                params.hueShift = 120
                params.satShift = 100
                params.lightShift = 0
            end
            updateSliderValue("hue", params.hueShift)
            updateSliderValue("saturation", params.satShift)
            updateSliderValue("lightness", params.lightShift)
            updatePreview()
        end
    }
    
    dlg:button{
        id="b_btn",
        text="B",
        onclick=function()
            -- Toggle Blue channel (H=240)
            if params.hueShift == -120 and params.satShift == 100 then
                params.hueShift = 0
                params.satShift = 0
                params.lightShift = 0
            else
                params.hueShift = -120  -- 240 degrees
                params.satShift = 100
                params.lightShift = 0
            end
            updateSliderValue("hue", params.hueShift)
            updateSliderValue("saturation", params.satShift)
            updateSliderValue("lightness", params.lightShift)
            updatePreview()
        end
    }
    
    dlg:button{
        id="a_btn",
        text="A",
        onclick=function()
            -- Toggle Alpha to max
            if params.alphaShift == 255 then
                params.alphaShift = 0
            else
                params.alphaShift = 255
            end
            updateSliderValue("alpha", params.alphaShift)
            updatePreview()
        end
    }
    
    dlg:newrow()
    
    dlg:check{
        id="preview",
        text="Preview",
        selected=true,
        onclick=function()
            if dlg.data.preview then
                updatePreview()
            else
                cel.image = sourceImage:clone()
                app.refresh()
            end
        end
    }
        
    dlg:slider{
        id="brightness",
        label="Brightness:",
        min=-255,
        max=255,
        value=0,
        onchange=function()
            params.brightnessShift = dlg.data.brightness
            updatePreview()
        end
    }
    
    dlg:slider{
        id="contrast",
        label="Contrast:",
        min=-100,
        max=100,
        value=0,
        onchange=function()
            -- Convert slider value to contrast factor (0.0 to 2.0+)
            local contrastValue = dlg.data.contrast
            params.contrastFactor = (contrastValue + 100) / 100
            updatePreview()
        end
    }
    
    dlg:newrow()
    
    dlg:check{
        id="preview_bc",
        text="Preview",
        selected=true,
        onclick=function()
            if dlg.data.preview_bc then
                updatePreview()
            else
                cel.image = sourceImage:clone()
                app.refresh()
            end
        end
    }
        
    dlg:slider{
        id="split",
        label="Split Position:",
        min=0,
        max=sourceImage.width,
        value=splitPosition,
        onchange=function()
            splitPosition = dlg.data.split
            updatePreview()
        end
    }
        
    dlg:button{
        id="minimize_btn",
        text="Minimize",
        visible=true,
        onclick=function()
            toggleMinimize()
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
    
    dlg:button{
        id="apply",
        text="Apply",
        onclick=function()
            app.transaction(function()
                local finalImage = applyAdjustmentsToImage(sourceImage, params, colorMode)
                cel.image = finalImage
            end)
            dlg:close()
        end
    }
    
    dlg:button{
        id="reset",
        text="Reset",
        onclick=function()
            dlg:modify{id="hue", value=0}
            dlg:modify{id="saturation", value=0}
            dlg:modify{id="lightness", value=0}
            dlg:modify{id="alpha", value=0}
            dlg:modify{id="brightness", value=0}
            dlg:modify{id="contrast", value=0}
            dlg:modify{id="useHSL", selected=false}
            dlg:modify{id="split", value=math.floor(sourceImage.width / 2)}
            params.hueShift = 0
            params.satShift = 0
            params.lightShift = 0
            params.alphaShift = 0
            params.brightnessShift = 0
            params.contrastFactor = 1.0
            params.useHSL = false
            splitPosition = math.floor(sourceImage.width / 2)
            cel.image = sourceImage:clone()
            app.refresh()
        end
    }
    
    dlg:button{
        id="cancel",
        text="Cancel",
        onclick=function()
            cel.image = sourceImage
            app.refresh()
            dlg:close()
        end
    }
    
    dlg:show{wait=false}
    
    if not dlg.data.apply then
        app.transaction(function()
            cel.image = sourceImage
        end)
    end
end

main()
