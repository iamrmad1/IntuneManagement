# Documentation Output Provider for Word 

#https://docs.microsoft.com/en-us/office/vba/api/overview/word
function Get-ModuleVersion
{
    '1.0.4'
}

function Invoke-InitializeModule
{
    if(!("Microsoft.Office.Interop.Word.Application" -as [Type]))
    {
        try
        {
            Add-Type -AssemblyName Microsoft.Office.Interop.Word
        }
        catch
        {
            Write-LogError "Failed to add Word Interop type. Cannot create word documents. Verify that Word is installed properly." $_.Exception
            return
        }
    }

    Add-OutputType ([PSCustomObject]@{
        Name="Word"
        Value="word"
        OutputOptions = (Add-WordOptionsControl)
        Activate = { Invoke-WordActivate @args }
        PreProcess = { Invoke-WordPreProcessItems @args }
        NewObjectGroup = { Invoke-WordNewObjectGroup @args }
        Process = { Invoke-WordProcessItem @args }
        PostProcess = { Invoke-WordPostProcessItems @args }
        ProcessAllObjects = { Invoke-WordProcessAllObjects @args }
    })

    $script:columnHeaders = @{
        Name="Inputs.displayNameLabel"
        Value="TableHeaders.value"
        Description="TableHeaders.description"
        GroupMode="SettingDetails.modeTableHeader" #assignmentTypeSelectionLabel?
        Group="TableHeaders.assignedGroups"
        Groups="TableHeaders.groups"
        useDeviceContext="SettingDetails.installContextLabel"
        uninstallOnDeviceRemoval="SettingDetails.UninstallOnRemoval"
        isRemovable="SettingDetails.installAsRemovable"
        vpnConfigurationId="PolicyType.vpn"
        Action="SettingDetails.actionColumnName"
        Schedule="ScheduledAction.List.schedule"
        MessageTemplate="ScheduledAction.Notification.messageTemplate"
        EmailCC="ScheduledAction.Notification.additionalRecipients"
        Filter="AssignmentFilters.assignmentFilterColumnHeader"
        Rule="ApplicabilityRules.GridLabel.Rule"
        ValueWithLabel="TableHeaders.value"
        Status="TableHeaders.status"
        CombinedValueWithLabel="TableHeaders.value"
        CombinedValue="TableHeaders.value"
        useDeviceLicensing="TableHeaders.licenseType"
        #filterMode="Filter mode" # Not in any string file yet 
    }    
}

function Add-WordOptionsControl
{
    $script:wordForm = Get-XamlObject ($global:AppRootFolder + "\Xaml\DocumentationWordOptions.xaml") -AddVariables

    $global:cbWordDocumentationProperties.ItemsSource = ("[ { Name: `"Simple (Name and Value)`",Value: `"simple`" }, { Name: `"Extended`",Value: `"extended`" }, { Name: `"Custom`",Value: `"custom`" }]" | ConvertFrom-Json)
    $global:cbWordDocumentationProperties.SelectedValue = (Get-Setting "Documentation" "WordExportProperties" "simple")
    $global:txtWordCustomProperties.Text = (Get-Setting "Documentation" "WordCustomDisplayProperties" "Name,Value,Category,SubCategory")

    $global:spWordCustomProperties.Visibility = (?: ($global:cbWordDocumentationProperties.SelectedValue -ne "custom") "Collapsed" "Visible")
    $global:txtWordCustomProperties.Visibility = (?: ($global:cbWordDocumentationProperties.SelectedValue -ne "custom") "Collapsed" "Visible")

    $global:txtWordDocumentTemplate.Text = Get-Setting "Documentation" "WordDocumentTemplate" ""
    $global:txtWordDocumentName.Text = (Get-Setting "Documentation" "WordDocumentName" "%MyDocuments%\%Organization%-%Date%.docx")
    
    $global:chkWordAddCategories.IsChecked = ((Get-Setting "Documentation" "WordAddCategories" "true") -ne "false")
    $global:chkWordAddSubCategories.IsChecked = ((Get-Setting "Documentation" "WordAddSubCategories" "true") -ne "false")
    
    $global:txtWordHeader1Style.Text = Get-Setting "Documentation" "WordHeader1Style" "Heading 1"
    $global:txtWordHeader2Style.Text = Get-Setting "Documentation" "WordHeader2Style" "Heading 2"
    $global:txtWordTableStyle.Text = Get-Setting "Documentation" "WordTableStyle" "Grid table 4 - Accent 3"
    $global:txtWordTableHeaderStyle.Text = Get-Setting "Documentation" "WordTableHeaderStyle" ""
    $global:txtWordCategoryHeaderStyle.Text = Get-Setting "Documentation" "WordCategoryHeaderStyle" ""
    $global:txtWordSubCategoryHeaderStyle.Text = Get-Setting "Documentation" "WordSubCategoryHeaderStyle" ""
    $global:txtWordContentControls.Text = Get-Setting "Documentation" "WordContentControls" "Year=;Address="
    $global:txtWordTitleProperty.Text = Get-Setting "Documentation" "WordTitleProperty" "Intune documentation"
    $global:txtWordSubjectProperty.Text = Get-Setting "Documentation" "WordSubjectProperty" "Intune documentation"
    

    $global:chkWordOpenDocument.IsChecked = ((Get-Setting "Documentation" "WordOpenDocument" "true") -ne "false")

    Add-XamlEvent $script:wordForm "browseWordDocumentTemplate" "add_click" {
        $of = [System.Windows.Forms.OpenFileDialog]::new()
        $of.Multiselect = $false
        $of.Filter = "Word Templates (*.dotx)|*.dotx"
        if($of.ShowDialog())
        {
            Set-XamlProperty $script:wordForm "txtWordDocumentTemplate" "Text" $of.FileName
            Save-Setting "Documentation" "WordDocumentTemplate" $of.FileName
        }                
    }
    
    Add-XamlEvent $script:wordForm "cbWordDocumentationProperties" "add_selectionChanged" {
        $global:spWordCustomProperties.Visibility = (?: ($this.SelectedValue -ne "custom") "Collapsed" "Visible")
        $global:txtWordCustomProperties.Visibility = (?: ($this.SelectedValue -ne "custom") "Collapsed" "Visible")
    }

    $script:wordForm
}
function Invoke-WordActivate
{
    #$global:chkWordAddCompanyName.IsChecked = (Get-SettingValue "AddCompanyName")
}

function Invoke-WordPreProcessItems
{
    Save-Setting "Documentation" "WordExportProperties" $global:cbWordDocumentationProperties.SelectedValue
    Save-Setting "Documentation" "WordCustomDisplayProperties" $global:txtWordCustomProperties.Text
    Save-Setting "Documentation" "WordDocumentTemplate" $global:txtWordDocumentTemplate.Text

    Save-Setting "Documentation" "WordAddCategories" $global:chkWordAddCategories.IsChecked
    Save-Setting "Documentation" "WordAddSubCategories" $global:chkWordAddSubCategories.IsChecked
    Save-Setting "Documentation" "WordOpenDocument" $global:chkWordOpenDocument.IsChecked

    Save-Setting "Documentation" "WordHeader1Style" $global:txtWordHeader1Style.Text
    Save-Setting "Documentation" "WordHeader2Style" $global:txtWordHeader2Style.Text
    Save-Setting "Documentation" "WordTableStyle" $global:txtWordTableStyle.Text
    Save-Setting "Documentation" "WordTableHeaderStyle" $global:txtWordTableHeaderStyle.Text
    Save-Setting "Documentation" "WordCategoryHeaderStyle" $global:txtWordCategoryHeaderStyle.Text
    Save-Setting "Documentation" "WordSubCategoryHeaderStyle" $global:txtWordSubCategoryHeaderStyle.Text
    Save-Setting "Documentation" "WordContentControls" $global:txtWordContentControls.Text
    Save-Setting "Documentation" "WordTitleProperty" $global:txtWordTitleProperty.Text
    Save-Setting "Documentation" "WordSubjectProperty" $global:txtWordSubjectProperty.Text
    
    try
    {
        $script:wordApp = New-Object -ComObject Word.Application
    }
    catch
    {
        Write-LogError "Failed to create Word App object. Word documentation aborted..." $_.Exception
        return $false
    }

    
    #$wordApp.Visible = $true

    if($global:txtWordDocumentTemplate.Text)
    {
        try
        {
            $script:doc = $wordApp.Documents.Add($global:txtWordDocumentTemplate.Text) 
        }
        catch
        {
            Write-LogError "Failed to create document based on tmeplate: $($global:txtWordDocumentTemplate.Text)" $_.Exception
        }
    }
    else
    {
        $script:doc = $wordApp.Documents.Add() 
    }

    #Get BuiltIn properties
    $script:builtInProps = @()
    $script:doc.BuiltInDocumentProperties | foreach-object { 

        $name = [System.__ComObject].invokemember("name",[System.Reflection.BindingFlags]::GetProperty,$null,$_,$null)
        try
        {
        $value = [System.__ComObject].invokemember("value",[System.Reflection.BindingFlags]::GetProperty,$null,$_,$null)
        }
        catch{}

        if($name)
        {
            $script:builtInProps += [PSCustomObject]@{
            Name = $name
            Value = $value
            }
        }
    }

    #Get Custom properties
    $script:customProps = @()
    $script:doc.CustomDocumentProperties | foreach-object { 

        $name = [System.__ComObject].invokemember("name",[System.Reflection.BindingFlags]::GetProperty,$null,$_,$null)
        try
        {
            $value = [System.__ComObject].invokemember("value",[System.Reflection.BindingFlags]::GetProperty,$null,$_,$null)
        }
        catch{}

        if($name)
        {
            $script:customProps += [PSCustomObject]@{
            Name = $name
            Value = $value
            }
        }
    }

    $script:wordStyles = @()
    $script:doc.Styles | foreach { 
        $script:wordStyles += [PSCUstomObject]@{
            Name=$_.NameLocal
            Type=$_.Type
            Style=$_
            }
    }

    $script:builtinStyles = [Enum]::GetNames([Microsoft.Office.Interop.Word.wdBuiltinStyle])

    if(-not $global:txtWordDocumentTemplate.Text)
    {
        $script:doc.Application.Templates.LoadBuildingBlocks()
        $BuildingBlocks = $script:doc.Application.Templates | Where {$_.name -eq 'Built-In Building Blocks.dotx'}
        if($BuildingBlocks)
        {    
            $coverPageName = ?? $global:txtWordCoverPage.Text 'Ion (Dark)'  
            try
            {
                $blocks = @()

                for($i = 1;$i -le $BuildingBlocks.BuildingBlockEntries.Count;$i++)
                {
                    $blocks += $BuildingBlocks.BuildingBlockEntries.Item($i)
                }
                
                $coverPages = (($blocks | Where { $_.Type.Index -eq 2 } | Select Name) | Sort -Property Name).Name

                if(($coverPages | measure).Count -gt 0)
                {
                    if($coverPageName -notin $coverPages)
                    {
                        Write-Log "$coverPageName not found in available Cover Page list. Using: $($coverPages[0])"
                        Write-Log "Available Cover Pages: $(($coverPages -join ","))"
                        $coverPageName = $coverPages[0]
                    }
                    else
                    {
                        Write-Log "Add Cover Page: $coverPageName"
                    }
                }

                $coverPage = $BuildingBlocks.BuildingBlockEntries.Item($coverPageName)
                $coverPage.Insert($script:wordApp.Selection.Range,$true) | Out-Null
                $script:wordApp.Selection.InsertNewPage()
            }
            catch 
            {
                Write-LogError "Failed to create Cover Page" $_.Exception
            }

            try
            {
                $coverPageProps = $script:doc.CustomXMLParts | where { $_.NamespaceURI -match "coverPageProps$" }
                if($coverPageProps)
                {
                    Write-Log "Available Cover Page properties for $($coverPageName): $(((([xml]$coverPageProps.DocumentElement.XML).ChildNodes[0].ChildNodes).Name -join ","))"
                }
            }
            catch{}

            try
            {
                $script:doc.TablesOfContents.Add($script:wordApp.Selection.Range) | out-null
                $script:wordApp.Selection.InsertNewPage()
            }
            catch
            {
                Write-LogError "Failed to create Table of Contents" $_.Exception
            }
        }
    }
}

function Invoke-WordPostProcessItems
{
    $userName = $global:me.displayName
    if($global:me.givenName -and $global:me.surname)
    {
        $userName = ($global:me.givenName + " " + $global:me.surname)
    }
    
    #Add properties - ToDo: This is static...
    Set-WordDocBuiltInProperty "wdPropertyTitle" (?? $global:txtWordTitleProperty.Text "Intune documentation")
    Set-WordDocBuiltInProperty "wdPropertySubject" (?? $global:txtWordSubjectProperty.Text "Intune documentation")
    Set-WordDocBuiltInProperty "wdPropertyAuthor" $userName
    Set-WordDocBuiltInProperty "wdPropertyCompany" $global:Organization.displayName
    Set-WordDocBuiltInProperty "wdPropertyKeywords" "Intune,Endpoint Manager,MEM"
    
    try
    {
        # ToDo: Add support for custom properties
        # Add: https://docs.microsoft.com/en-us/dotnet/api/microsoft.office.core.documentproperties.add?view=office-pia
        # Types: https://docs.microsoft.com/en-us/dotnet/api/microsoft.office.core.msodocproperties?view=office-pia
        #$coverPageProps = $script:doc.CustomXMLParts | where { $_.NamespaceURI -match "coverPageProps$" }
        #[System.__ComObject].InvokeMember("add",[System.Reflection.BindingFlags]::InvokeMethod,$null,$script:doc.CustomDocumentProperties,([array]("PropName", $false, 4, "PropValue")))
        
        $ContentControlProperties = $global:txtWordContentControls.Text #"Year=;Address=TestAddress"
        foreach($ccObj in $ContentControlProperties.Split(';'))
        {
            $ccName,$ccVal = $ccObj.Split('=')
            Set-WordContentControlText $ccName $ccVal
        }
    }
    catch {}

    #update fields, ToC etc.
    $script:doc.Fields | ForEach-Object -Process { $_.Update() | Out-Null } 
    $script:doc.TablesOfContents | ForEach-Object -Process { $_.Update() | Out-Null }
    $script:doc.TablesOfFigures | ForEach-Object -Process { $_.Update() | Out-Null }
    $script:doc.TablesOfAuthorities | ForEach-Object -Process { $_.Update() | Out-Null }

    $fileName = $global:txtWordDocumentName.Text
    if(-not $fileName)
    {
        $fileName = "%MyDocuments%\%Organization%-%Date%.docx"
    }

    $fileName = Expand-FileName $fileName

    $format = [Microsoft.Office.Interop.Word.WdSaveFormat]::wdFormatDocumentDefault

    try
    {
        $script:doc.SaveAs2([ref]$fileName,[ref]$format)
        Write-Log "Document $fileName saved successfully"
    }
    catch
    {
        Write-LogError "Failed to save file $fileName" $_.Excption
    }

    if($global:chkWordOpenDocument.IsChecked -eq $true)
    {
        $script:wordApp.Visible = $true
        $script:wordApp.WindowState = [Microsoft.Office.Interop.Word.WdWindowState]::wdWindowStateMaximize
        $script:wordApp.Activate()
        [Console.Window]::SetForegroundWindow($script:wordApp.ActiveWindow.Hwnd) | Out-Null
    }
    else
    {
        $script:doc.Close([Microsoft.Office.Interop.Word.WdSaveOptions]::wdDoNotSaveChanges)
        $script:wordApp.Quit()
    }
}

function Set-WordContentControlText 
{
    param($controlName, $value)

    if(-not $controlName) { return }

    try
    {
        $ctrl = $script:doc.SelectContentControlsByTitle($controlName)

        if($ctrl) 
        {
            Write-LogDebug "Update ContentControl $controlName (Type: $($ctrl[1].Type))"
            if($ctrl[1].Type -eq 6)
            {
                if($ctrl[1].DateDisplayFormat)
                {
                    $ctrl[1].Range.Text = (Get-Date).ToString($ctrl[1].DateDisplayFormat)
                }
                else
                {
                    $ctrl[1].Range.Text = (Get-Date).ToShortDateString()
                }
            }
            else
            {
                if(-not $value) { return }

                $ctrl[1].Range.Text = $value
            }
        }
        else
        {
            Write-Log "No ContentControl found with name $controlName" 2
        }
    }
    catch
    {
        Write-LogError "Failed to set ContentControl $controlName" $_.Exception
    }
}

function Invoke-WordNewObjectGroup
{
    param($obj, $documentedObj)

    $objectTypeString = Get-ObjectTypeString $obj.Object $obj.ObjectType

    Add-DocText (?? $objectTypeString $obj.ObjectType.Title) $global:txtWordHeader1Style.Text
}

function Invoke-WordProcessItem
{
    param($obj, $objectType, $documentedObj)

    if(!$documentedObj -or !$obj -or !$objectType) { return }

    $objName = Get-GraphObjectName $obj $objectType

    Add-DocText $objName $global:txtWordHeader2Style.Text
    
    $script:doc.Application.Selection.TypeParagraph()  

    try 
    {
        #TableHeaders.value
        #Inputs.displayNameLabel

        foreach($tableType in @("BasicInfo","FilteredSettings"))
        {
            if($tableType -eq "BasicInfo")
            {
                $properties = @("Name","Value")
            }
            elseif($global:cbWordDocumentationProperties.SelectedValue -eq 'extended' -and $documentedObj.DisplayProperties)
            {
                $properties = @("Name","Value","Description")
            }
            elseif($global:cbWordDocumentationProperties.SelectedValue -eq 'custom' -and $global:txtWordCustomProperties.Text)
            {
                $properties = @()
                
                foreach($prop in $global:txtWordCustomProperties.Text.Split(","))
                {
                    # This will add language support for custom colument (or replacing existing header)
                    $propInfo = $prop.Split('=')
                    if(($propInfo | measure).Count -gt 1)
                    {
                        $properties += $propInfo[0] 
                        Set-WordColumnHeaderLanguageId $propInfo[0] $propInfo[1]
                    }
                    else
                    {
                        $properties += $prop
                    }
                }
            }        
            else
            {
                $properties = (?? $documentedObj.DefaultDocumentationProperties (@("Name","Value")))
            }
            
            $lngId = ?: ($tableType -eq "BasicInfo") "SettingDetails.basics" "TableHeaders.settings" -AddCategories

            Add-DocTableItems $obj $objectType ($documentedObj.$tableType) $properties $lngId `
                -AddCategories:($global:chkWordAddCategories.IsChecked -eq $true) `
                -AddSubcategories:($global:chkWordAddSubCategories.IsChecked -eq $true)
        }

        if(($documentedObj.ComplianceActions | measure).Count -gt 0)
        {
            $properties = @("Action","Schedule","MessageTemplate","EmailCC")

            Add-DocTableItems $obj $objectType $documentedObj.ComplianceActions $properties "Category.complianceActionsLabel"
        }

        if(($documentedObj.ApplicabilityRules | measure).Count -gt 0)
        {
            $properties = @("Rule","Property","Value")

            Add-DocTableItems $obj $objectType $documentedObj.ApplicabilityRules $properties "SettingDetails.applicabilityRules"
        }

        if(($documentedObj.Assignments | measure).Count -gt 0)
        {
            $params = @{}
            if($documentedObj.Assignments[0].RawIntent)
            {
                $properties = @("GroupMode","Group","Filter","FilterMode")
            
                $settingsObj = $documentedObj.Assignments | Where { $_.Settings -ne $null } | Select -First 1

                if($settingsObj)
                {
                    foreach($objProp in $settingsObj.Settings.Keys)
                    {
                        if($objProp -in $properties) { continue }
                        if($objProp -in @("Category","RawIntent")) { continue }
                        $properties += ("Settings." + $objProp)
                    }
                }
            }
            else
            {
                $isFilterAssignment = $false
                foreach($assignment in $documentedObj.Assignments)
                {
                    if(($assignment.target.PSObject.Properties | Where Name -eq "deviceAndAppManagementAssignmentFilterType"))
                    {
                        $isFilterAssignment = $true
                        break
                    }
                }
                $properties = @("Group")
                if($isFilterAssignment)
                {
                    $properties += @("Filter","FilterMode")
                }
                $params.Add("AddCategories", $true)
            }

            Add-DocTableItems $obj $objectType $documentedObj.Assignments $properties "TableHeaders.assignments" @params
        }
    }
    catch 
    {
        Write-LogError "Failed to process object $objName" $_.Exception
    }
}

function Invoke-WordProcessAllObjects
{
    param($allObjectTypeObjects)

    if(($allObjectTypeObjects | measure).Count -eq 0) { return }

    $tmpObj = $allObjectTypeObjects | Select -First 1
    if(-not $tmpObj) { return }

    $objectType = $tmpObj.Object.ObjectType
    if($objectType.Id -eq "ScopeTags")
    {
        $objTypeName = Get-LanguageString "SettingDetails.scopeTags"

        Add-DocText $objTypeName $global:txtWordHeader2Style.Text

        $script:doc.Application.Selection.TypeParagraph()  

        $items = @()

        $nameLabel = Get-LanguageString "Inputs.displayNameLabel"
        $descriptionLable = Get-LanguageString "TableHeaders.description" 
        foreach($obj in $allObjectTypeObjects.Object.Object)
        {
            $items += [PSCustomObject]@{
                $nameLabel = $obj.displayName
                ID = $obj.Id
                $descriptionLable = $obj.Description
            }
        }

        $items = $items | Sort -Property $nameLabel

        $properties = @($nameLabel,"id",$descriptionLable)

        Add-DocTableItems $tmpObj.Object.Object $tmpObj.Object.ObjectType $items $properties -captionOverride (Get-LanguageString "SettingDetails.scopeTags")
    }
}

function Invoke-WordTranslateColumnHeader
{
    param($columnName)

    $lngText = ""
    if($script:columnHeaders.ContainsKey($columnName))
    {
        $lngText = Get-LanguageString $script:columnHeaders[$columnName]
    }

    (?? $lngText $columnName)
}

function Invoke-WordCustomProcessItems
{
    param($obj, $documentedObj)

}

function Set-WordColumnHeaderLanguageId
{
    param($columnName, $lngId)

    if(-not $script:columnHeaders -or -not $lngId) { return }

    if($script:columnHeaders.ContainsKey($columnName))
    {
        $script:columnHeaders[$columnName] = $lngId
    }
    else
    {
        $script:columnHeaders.Add($columnName, $lngId)
    }
}

function Add-DocTableItems
{
    param($obj, $objectType, $items, $properties, $lngId, [switch]$AddCategories, [switch]$AddSubcategories, $captionOverride)

    $tblHeaderStyle = $global:txtWordTableHeaderStyle.Text
    $tblCategoryStyle = $global:txtWordCategoryHeaderStyle.Text
    $tblSubCategoryStyle = $global:txtWordSubCategoryHeaderStyle.Text

    $range = $script:doc.application.selection.range
    
    $script:docTable = $script:doc.Tables.Add($range, ($items.Count + 1), $properties.Count, [Microsoft.Office.Interop.Word.WdDefaultTableBehavior]::wdWord9TableBehavior, [Microsoft.Office.Interop.Word.WdAutoFitBehavior]::wdAutoFitWindow)
    $script:docTable.ApplyStyleHeadingRows = $true
    Set-DocObjectStyle $script:docTable $global:txtWordTableStyle.Text

    if($captionOverride)
    {
        $caption = $captionOverride
    }
    elseif($lngId)
    {
        $caption = "$((Get-LanguageString $lngId)) - $((Get-GraphObjectName $obj $objectType))"
    }
    else
    {
        $caption = "$((Get-GraphObjectName $obj $objectType)) ($($objectType.Title))"
    }

    $i = 1
    foreach($prop in $properties)
    {
        $script:docTable.Cell(1, $i).Range.Text = (Invoke-WordTranslateColumnHeader ($prop.Split(".")[-1]))
        $i++
    }

    if(!(Set-DocObjectStyle $script:docTable.Rows(1).Range $tblHeaderStyle))
    {
        $script:docTable.Rows(1).Range.Font.Size += 2
        $script:docTable.Rows(1).Range.Font.Bold = $true
    }    
    
    $curCategory = ""
    $curSubCategory = ""

    $row = 2
    foreach($itemObj in $items)
    {
        try 
        {
            $i = 1
            foreach($prop in $properties)
            {
                try
                {
                    # This adds support for properties like Settings.PropName
                    $propArr = $prop.Split('.')
                    $tmpObj = $itemObj
                    $propName = $propArr[-1]
                    for($x = 0; $x -lt ($propArr.Count - 1);$x++)
                    {
                        $tmpObj = $tmpObj."$($propArr[$x])"
                    }
                    $script:docTable.Cell($row, $i).Range.Text = "$($tmpObj.$propName)"
                }
                catch
                {
                    Write-LogError "Failed to add property value for $prop" $_.Exception
                }
                $i++
            }
        
            if($itemObj.Category -and $curCategory -ne $itemObj.Category -and $AddCategories -eq $true)
            {
                # Insert row for the Category above the new row
                $script:docTable.Rows.Add($script:docTable.Rows.Item($row)) | Out-Null
                $script:docTable.Rows.Item($row).Cells.Merge()
                $script:docTable.Cell($row, 1).Range.Text = $itemObj.Category
                
                if(!(Set-DocObjectStyle $script:docTable.Rows($row).Range $tblCategoryStyle))
                {
                    $script:docTable.Rows($row).Range.Font.Size += 2
                    $script:docTable.Rows($row).Range.Font.Italic = $true
                }
                $row++
                $curCategory = $itemObj.Category
                $curSubCategory = ""
            }

            if($itemObj.SubCategory -and $curSubCategory -ne $itemObj.SubCategory -and $AddSubcategories -eq $true)
            {
                # Insert row for the SubCategory above the new row
                $script:docTable.Rows.Add($script:docTable.Rows.Item($row)) | Out-Null
                $script:docTable.Rows.Item($row).Cells.Merge()
                $script:docTable.Cell($row, 1).Range.Text = $itemObj.SubCategory
                
                if(!(Set-DocObjectStyle $script:docTable.Rows($row).Range $tblSubCategoryStyle))
                {
                    $script:docTable.Rows($row).Range.Font.Italic = $true
                }
                $row++
                $curSubCategory = $itemObj.SubCategory
            }
        }
        catch 
        {
            Write-Log "Failed to process property" 2    
        }

        $row++
    }
    
    # -2 = Table, 1 = Below
    $script:docTable.Application.Selection.InsertCaption(-2, ". $caption", $null, 1)
    
    # Add new row after the table
    #$script:doc.Application.Selection.InsertParagraphAfter()    
    $script:doc.Application.Selection.TypeParagraph()
    #$script:doc.Application.Selection.TypeParagraph()
}

function Get-DocStyle
{
    param($styleName)

    $tmpStyle = ($script:wordStyles | Where Name -like $styleName).Style
    
    # BuiltIn Styles
    #[Enum]::GetNames([Microsoft.Office.Interop.Word.wdBuiltinStyle])
    
    if(!$tmpStyle)
    {
        Write-Log "Style $styleName not found"
    }
    $tmpStyle
}

function Add-DocText
{
    param($text, $style, [switch]$SkipAddParagraph)

    Set-DocObjectStyle $script:doc.application.selection $style | Out-Null
    
    $script:doc.Application.Selection.TypeText($text)  

    if($SkipAddParagraph -ne $true)
    {
        # Add new paragraph by default
        $script:doc.Application.Selection.TypeParagraph()               
    }
}

function Invoke-DocGoToEnd
{
    $script:doc.Application.Selection.goto([Microsoft.Office.Interop.Word.WdGoToItem]::wdGoToBookmark, $null, $null, '\EndOfDoc') | Out-Null
}

function Set-WordDocBuiltInProperty
{
    param($propertyName, $value)

    try
    {
        $script:doc.BuiltInDocumentProperties([Microsoft.Office.Interop.Word.WdBuiltInProperty]$propertyName) = $value
    }
    catch
    {
        Write-LogError "Failed to set built in property $propertyName to $value"  $_.Exception
    }
}

function Set-DocObjectStyle
{
    param($docObj, $objStyle)

    $styleSet = $false
    if($docObj -and $objStyle)
    {
        try
        {
            if(($script:builtinStyles | Where { $_ -eq $objStyle }))
            {
                $docObj.style = [Microsoft.Office.Interop.Word.wdBuiltinStyle]$objStyle
            }
            else
            {
                $docObj.style = $objStyle
            }
            $styleSet = $true
        }
        catch
        {
            Write-Log "Failed to set style: $objStyle" 3
        }
    }
    $styleSet
}
