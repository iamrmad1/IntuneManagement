<#
This moule extends the EnpointManager view with a Compare option.

This will compare an Intune object with an exported file.

The properties of the compared objects will be added to a DataGrid and the non-matching properties will be highlighted

Objects can be compared based on Properties or Documentatation info.

#>

function Get-ModuleVersion
{
    '1.0.7'
}

function Invoke-InitializeModule
{
    $global:comparisonTypes = $null
    $global:compareProviders = $null
    $script:CompareProviderOptionsCache = $null

    $script:defaultCompareProps = [Collections.Generic.List[String]]@('ObjectName', 'Id', 'Type', 'Category', 'SubCategory', 'Property', 'Value1', 'Value2', 'Match')
    
    # Make sure we add the default providers
    Add-CompareProvider
    Add-ComparisonTypes

    $script:saveType = @(
        [PSCustomObject]@{
            Name="One file for each object type"
            Value="objectType"
        },
        [PSCustomObject]@{
            Name="One file for all objects"
            Value="all"
        }
    )
}

function Add-CompareProvider
{
    param($compareProvider)

    if(-not $global:compareProviders)
    {
        $global:compareProviders = @()
    }

    if($global:compareProviders.Count -eq 0)
    {
        $global:compareProviders += [PSCustomObject]@{
            Name = "Exported File"
            Value = "export"
            ObjectCompare = { Compare-ObjectsBasedonProperty @args }
            BulkCompare = { Start-BulkCompareExportObjects @args }
            ProviderOptions = "CompareExportOptions"
            Activate = { Invoke-ActivateCompareExportObjects @args }
        }

        $global:compareProviders += [PSCustomObject]@{
            Name = "Named Objects"            
            Value = "name"
            BulkCompare = { Start-BulkCompareNamedObjects @args }
            ProviderOptions = "CompareNamedOptions"
            Activate = { Invoke-ActivateCompareNamesObjects @args }
            RemoveProperties = @("Id")
        }        

        $global:compareProviders += [PSCustomObject]@{
            Name = "Existing objects"
            Value = "existing"
            Compare = { Compare-ObjectsBasedonDocumentation @args }
        }
    }

    if(!$compareProvider) { return }

    $global:compareProviders += $compareProvider
}

function Add-ComparisonTypes
{
    param($comparisonType)

    if(-not $global:comparisonTypes)
    {
        $global:comparisonTypes = @()
    }

    if($global:comparisonTypes.Count -eq 0)
    {
        $global:comparisonTypes += [PSCustomObject]@{
            Name = "Property"
            Value = "property"
            Compare = { Compare-ObjectsBasedonProperty @args }
            RemoveProperties = @('Category','SubCategory')
        }

        $global:comparisonTypes += [PSCustomObject]@{
            Name = "Documentation"
            Value = "doc"
            Compare = { Compare-ObjectsBasedonDocumentation @args }
        }
    }

    if(!$comparisonType) { return }

    $global:comparisonTypes += $comparisonType
}

function Invoke-ShowMainWindow
{
    $button = [System.Windows.Controls.Button]::new()
    $button.Content = "Compare"
    $button.Name = "btnCompare"
    $button.MinWidth = 100
    $button.Margin = "0,0,5,0" 
    $button.IsEnabled = $false
    $button.ToolTip = "Compare object with exported file"
    $global:dgObjects.add_selectionChanged({
        Set-XamlProperty $global:dgObjects.Parent "btnCompare" "IsEnabled" (?: ($global:dgObjects.SelectedItem -eq $null) $false $true)
    })

    $button.Add_Click({ 
        Show-CompareForm $global:dgObjects.SelectedItem
    })    

    $global:spSubMenu.RegisterName($button.Name, $button)

    $global:spSubMenu.Children.Insert(0, $button)
}

function Invoke-ViewActivated
{
    if($global:currentViewObject.ViewInfo.ID -ne "IntuneGraphAPI") { return }
    
    $tmp = $mnuMain.Items | Where Name -eq "EMBulk"
    if($tmp)
    {
        $tmp.AddChild(([System.Windows.Controls.Separator]::new())) | Out-Null
        $subItem = [System.Windows.Controls.MenuItem]::new()
        $subItem.Header = "_Compare"
        $subItem.Add_Click({Show-CompareBulkForm})
        $tmp.AddChild($subItem)
    }
}

function Show-CompareBulkForm
{
    $script:form = Get-XamlObject ($global:AppRootFolder + "\Xaml\BulkCompare.xaml") -AddVariables
    if(-not $script:form) { return }

    $global:cbCompareProvider.ItemsSource = @(($global:compareProviders | Where BulkCompare -ne $null))
    $global:cbCompareProvider.SelectedValue = (Get-Setting "Compare" "Provider" "export")

    $global:cbCompareSave.ItemsSource = @($script:saveType)
    $global:cbCompareSave.SelectedValue = (Get-Setting "Compare" "SaveType" "objectType")

    $global:cbCompareType.ItemsSource = $global:comparisonTypes | Where ShowOnBulk -ne $false 
    $global:cbCompareType.SelectedValue = (Get-Setting "Compare" "Type" "property")

    $global:cbCompareCSVDelimiter.ItemsSource = @("", ",",";","-","|")
    $global:cbCompareCSVDelimiter.SelectedValue = (Get-Setting "Compare" "Delimiter" ";")

    $script:compareObjects = @()
    foreach($objType in $global:lstMenuItems.ItemsSource)
    {
        if(-not $objType.Title) { continue }

        $script:compareObjects += New-Object PSObject -Property @{
            Title = $objType.Title
            Selected = $true
            ObjectType = $objType
        }
    }

    $column = Get-GridCheckboxColumn "Selected"
    $global:dgObjectsToCompare.Columns.Add($column)

    $column.Header.IsChecked = $true # All items are checked by default
    $column.Header.add_Click({
            foreach($item in $global:dgObjectsToCompare.ItemsSource)
            {
                $item.Selected = $this.IsChecked
            }
            $global:dgObjectsToCompare.Items.Refresh()
        }
    ) 

    # Add Object type column
    $binding = [System.Windows.Data.Binding]::new("Title")
    $column = [System.Windows.Controls.DataGridTextColumn]::new()
    $column.Header = "Object type"
    $column.IsReadOnly = $true
    $column.Binding = $binding
    $global:dgObjectsToCompare.Columns.Add($column)

    $global:dgObjectsToCompare.ItemsSource = $script:compareObjects

    Add-XamlEvent $script:form "btnClose" "add_click" {
        $script:form = $null
        Show-ModalObject 
    }

    Add-XamlEvent $script:form "btnStartCompare" "add_click" {
        Write-Status "Compare objects"
        Save-Setting "Compare" "Provider" $global:cbCompareProvider.SelectedValue
        Save-Setting "Compare" "Type" $global:cbCompareType.SelectedValue
        Save-Setting "Compare" "Delimiter" $global:cbCompareCSVDelimiter.SelectedValue
        if($global:cbCompareProvider.SelectedItem.BulkCompare)
        {
            & $global:cbCompareProvider.SelectedItem.BulkCompare
        }
        Write-Status "" 
    }

    $global:cbCompareProvider.Add_SelectionChanged({        
        Set-CompareProviderOptions $this
    })       

    Set-CompareProviderOptions $global:cbCompareProvider

    Show-ModalForm "Bulk Compare Objects" $script:form -HideButtons
}

function Set-CompareProviderOptions
{
    param($control)

    $providerOptions = $null
    $firstTime = $false
    if($control.SelectedItem.ProviderOptions)
    {
        if($script:CompareProviderOptionsCache -isnot [Hashtable]) { $script:CompareProviderOptionsCache = @{} }
        if($script:CompareProviderOptionsCache.Keys -contains $control.SelectedValue)
        {
            $providerOptions = $script:CompareProviderOptionsCache[$control.SelectedValue]
        }
        else
        {
            $providerOptions = Get-XamlObject ($global:AppRootFolder + "\Xaml\$($control.SelectedItem.ProviderOptions).xaml") -AddVariables
            if($providerOptions)
            {
                $firstTime = $true            
                $script:CompareProviderOptionsCache.Add($control.SelectedValue, $providerOptions)
            }
            else
            {
                Write-Log "Failed to create options for $($control.SelectedItem.Name)" 3
            }
        }
        $global:ccContentProviderOptions.Content = $providerOptions
    }
    else
    {
       $global:ccContentProviderOptions.Content = $null 
    }
    $global:ccContentProviderOptions.Visibility = (?: ($global:ccContentProviderOptions.Content -eq $null) "Collapsed" "Visible")

    if($control.SelectedItem.Activate)
    {
        if($firstTime)
        {
            Write-Log "Initialize $($global:cbCompareProvider.SelectedItem.Name) provider options"
        }
    
        & $control.SelectedItem.Activate $providerOptions $firstTime
    }    
}

function Invoke-ActivateCompareExportObjects
{
    param($providerOptions, $firstTime)

    if($firstTime)
    {
        $path = Get-Setting "" "LastUsedFullPath"
        if($path) 
        {
            $path = [IO.Directory]::GetParent($path).FullName
        }        
        Set-XamlProperty $providerOptions "txtExportPath" "Text" (?? $path (Get-SettingValue "RootFolder"))

        Add-XamlEvent $providerOptions "browseExportPath" "add_click" ({
            $folder = Get-Folder (Get-XamlProperty $this.Parent "txtExportPath" "Text") "Select root folder for compare"
            if($folder)
            {
                Set-XamlProperty $this.Parent "txtExportPath" "Text" $folder
            }
        })
    }
}

function Invoke-ActivateCompareNamesObjects
{
    param($providerOptions, $firstTime)

    if($providerOptions -and $firstTime)
    {
        Set-XamlProperty $providerOptions "txtCompareSource" "Text" (Get-Setting "Compare" "CompareSource" "")
        Set-XamlProperty $providerOptions "txtCompareWith" "Text" (Get-Setting "Compare" "CompareWith" "")

        Set-XamlProperty $providerOptions "txtSavePath" "Text" (Get-Setting "Compare" "SavePath" "")
        Add-XamlEvent $providerOptions "browseSavePath" "add_click" ({
            $folder = Get-Folder (Get-XamlProperty $this.Parent "txtSavePath" "Text") "Select folder"
            if($folder)
            {
                Set-XamlProperty $this.Parent "txtSavePath" "Text" $folder
            }
        })
    }    
}

function Start-BulkCompareNamedObjects
{
    Write-Log "****************************************************************"
    Write-Log "Start bulk Named Objects compare"
    Write-Log "****************************************************************"
    $compareObjectsResult = @()

    $compareSource = (Get-XamlProperty $global:ccContentProviderOptions.Content "txtCompareSource" "Text")
    $compareWith = (Get-XamlProperty $global:ccContentProviderOptions.Content "txtCompareWith" "Text")    

    if(-not $compareSource -or -not $compareWith)
    {
        [System.Windows.MessageBox]::Show("Both source and compare name patterns must be specified", "Error", "OK", "Error")
        return
    }

    Save-Setting "Compare" "CompareSource" $compareSource
    Save-Setting "Compare" "CompareWith" $compareWith

    Invoke-BulkCompareNamedObjects $compareSource $compareWith

    Write-Log "****************************************************************"
    Write-Log "Bulk compare Named Objects finished"
    Write-Log "****************************************************************"
    Write-Status ""
}

function Invoke-BulkCompareNamedObjects
{
    param($sourcePattern, $comparePattern)

    $outputType = $global:cbCompareSave.SelectedValue

    Save-Setting "Compare" "SaveType" $outputType
    
    $compResultValues = @()
    $compareObjectsResult = @()
    
    $outputFolder = (Get-XamlProperty $global:ccContentProviderOptions.Content "txtSavePath" "Text")
    if(-not $outputFolder)
    {
        $outputFolder = Expand-FileName "%MyDocuments%"
    }

    $compareProps = $script:defaultCompareProps
    
    foreach($removeProp in $global:cbCompareProvider.SelectedItem.RemoveProperties)
    {
        $compareProps.Remove($removeProp) | Out-Null
    }

    foreach($removeProp in $global:cbCompareType.SelectedItem.RemoveProperties)
    {
        $compareProps.Remove($removeProp) | Out-Null
    }

    foreach($item in ($global:dgObjectsToCompare.ItemsSource | where Selected -eq $true))
    { 
        Write-Status "Compare $($item.ObjectType.Title) objects" -Force -SkipLog
        Write-Log "----------------------------------------------------------------"
        Write-Log "Compare $($item.ObjectType.Title) objects"
        Write-Log "----------------------------------------------------------------"
    
        $graphObjects = @(Get-GraphObjects -property $item.ObjectType.ViewProperties -objectType $item.ObjectType)
        
        $nameProp = ?? $item.ObjectType.NameProperty "displayName"

        foreach($graphObj in ($graphObjects | Where { $_.Object."$($nameProp)" -imatch [regex]::Escape($sourcePattern) }))
        {
            $sourceName = $graphObj.Object."$($nameProp)"
            $compareName  = $sourceName -ireplace [regex]::Escape($sourcePattern),$comparePattern

            $compareObj = $graphObjects | Where { $_.Object."$($nameProp)" -eq $compareName -and $_.Object.'@OData.Type' -eq $graphObj.Object.'@OData.Type' }
        
            if(($compareObj | measure).Count -gt 1)
            {
                Write-Log "Multiple objects found with name $compareName. Compare will not be performed" 2
                continue
            }
            elseif($compareObj)
            {
                $sourceObj = Get-GraphObject $graphObj.Object $graphObj.ObjectType 
                $compareObj = Get-GraphObject $compareObj.Object $compareObj.ObjectType 
                $compareProperties = Compare-Objects $sourceObj.Object $compareObj.Object $sourceObj.ObjectType                
            }
            else
            {
                $sourceObj = Get-GraphObject $graphObj.Object $graphObj.ObjectType 
                # Add objects that are exported but deleted/not imported etc.
                Write-Log "Object '$((Get-GraphObjectName $graphObj.Object $graphObj.ObjectType))' with id $($graphObj.Object.Id) has no matching object with the compare pattern" 2
                $compareProperties = @([PSCustomObject]@{
                        Object1Value = (Get-GraphObjectName $graphObj.Object $graphObj.ObjectType)
                        Object2Value = $null
                        Match = $false
                    })
            }

            $compareObjectsResult += [PSCustomObject]@{
                Object1 = $sourceObj.Object
                Object2 = $compareObj.Object
                ObjectType = $item.ObjectType
                Id = $sourceObj.Object.Id
                Result = $compareProperties
            }          
        }

        if($outputType -eq "objectType")
        {
            $compResultValues = @()
        }

        foreach($compObj in @($compareObjectsResult | Where { $_.ObjectType.Id -eq $item.ObjectType.Id }))
        {
            $objName = Get-GraphObjectName (?? $compObj.Object1 $compObj.Object2) $item.ObjectType
            foreach($compValue in $compObj.Result)
            {
                $compResultValues += [PSCustomObject]@{
                    ObjectName = $objName
                    Id = $compObj.Id
                    Type = $compObj.ObjectType.Title
                    ODataType = $compObj.Object1.'@OData.Type'
                    Property = $compValue.PropertyName
                    Value1 = $compValue.Object1Value
                    Value2 = $compValue.Object2Value
                    Category = $compValue.Category
                    SubCategory = $compValue.SubCategory
                    Match = $compValue.Match
                }
            }
        }

        if($outputType -eq "objectType")
        {
            $fileName = Remove-InvalidFileNameChars (Expand-FileName "Compare-$($graphObj.ObjectType.Id)-$sourcePattern-$comparePattern-%DateTime%.csv")
            Save-BulkCompareResults $compResultValues (Join-Path $outputFolder $fileName) $compareProps
        }        
    }
    #$fileName = Expand-FileName $fileName

    if($compareObjectsResult.Count -eq 0)
    {
        [System.Windows.MessageBox]::Show("No objects were comparced. Verify name patterns", "Error", "OK", "Error")
    }
    elseif($outputType -eq "all")
    {
        $fileName = Remove-InvalidFileNameChars (Expand-FileName "Compare-$sourcePattern-$comparePattern-%DateTime%.csv")
        Save-BulkCompareResults $compResultValues (Join-Path $outputFolder $fileName) $compareProps
    }       
}

function Start-BulkCompareExportObjects
{
    Write-Log "****************************************************************"
    Write-Log "Start bulk Exported Objects compare"
    Write-Log "****************************************************************"
    $compareObjectsResult = @()
    $rootFolder = (Get-XamlProperty $global:ccContentProviderOptions.Content "txtExportPath" "Text")
    
    $compareProps = $script:defaultCompareProps
    
    foreach($removeProp in $global:cbCompareProvider.SelectedItem.RemoveProperties)
    {
        $compareProps.Remove($removeProp) | Out-Null
    }

    foreach($removeProp in $global:cbCompareType.SelectedItem.RemoveProperties)
    {
        $compareProps.Remove($removeProp) | Out-Null
    }

    if(-not $rootFolder)
    {
        [System.Windows.MessageBox]::Show("Root folder must be specified", "Error", "OK", "Error")
        return
    }

    if([IO.Directory]::Exists($rootFolder) -eq $false)
    {
        [System.Windows.MessageBox]::Show("Root folder $rootFolder does not exist", "Error", "OK", "Error")
        return
    }
    
    $outputType = $global:cbCompareSave.SelectedValue
    Save-Setting "Compare" "SaveType" $outputType

    $compResultValues = @()

    foreach($item in ($global:dgObjectsToCompare.ItemsSource | where Selected -eq $true))
    { 
        Write-Status "Compare $($item.ObjectType.Title) objects" -Force -SkipLog
        Write-Log "----------------------------------------------------------------"
        Write-Log "Compare $($item.ObjectType.Title) objects"
        Write-Log "----------------------------------------------------------------"

        $folder = Join-Path $rootFolder $item.ObjectType.Id
        
        if([IO.Directory]::Exists($folder))
        {
            Save-Setting "" "LastUsedFullPath" $folder
        
            $graphObjects = @(Get-GraphObjects -property $item.ObjectType.ViewProperties -objectType $item.ObjectType)        

            foreach ($fileObj in @(Get-GraphFileObjects $folder -ObjectType $item.ObjectType))
            {                
                if(-not $fileObj.Object.Id)
                {
                    Write-Log "Object from file '$($fileObj.FullName)' has no Id property. Compare not supported" 2
                    continue
                }
                $curObject = $graphObjects | Where { $_.Object.Id -eq $fileObj.Object.Id }

                if(-not $curObject)
                {
                    # Add objects that are exported but deleted
                    Write-Log "Object '$((Get-GraphObjectName $fileObj.Object $fileObj.ObjectType))' with id $($fileObj.Object.Id) not found in Intune. Deleted?" 2
                    $compareProperties = @([PSCustomObject]@{
                            Object1Value = $null
                            Object2Value = (Get-GraphObjectName $fileObj.Object $item.ObjectType)
                            Match = $false
                        })
                }
                else
                {
                    $sourceObj = Get-GraphObject $curObject.Object $curObject.ObjectType
                    $fileObj.Object | Add-Member Noteproperty -Name "@ObjectFromFile" -Value $true -Force 
                    $compareProperties = Compare-Objects $sourceObj.Object $fileObj.Object $item.ObjectType                    
                }

                $compareObjectsResult += [PSCustomObject]@{
                    Object1 = $curObject.Object
                    Object2 = $fileObj.Object
                    ObjectType = $item.ObjectType
                    Id = $fileObj.Object.Id
                    Result = $compareProperties
                }                
            }

            foreach($graphObj in $graphObjects)
            {
                # Add objects that are not exported
                if(($compareObjectsResult | Where { $_.Id -eq $graphObj.Id})) { continue }

                $compareObjectsResult += [PSCustomObject]@{
                    Object1 = $curObject.Object
                    Object2 = $null
                    ObjectType = $item.ObjectType
                    Id = $graphObj.Id
                    Result = @([PSCustomObject]@{
                        Object1Value = (Get-GraphObjectName $graphObj.Object $item.ObjectType)
                        Object2Value = $null
                        Match = $false
                    })
                }
            }

            if($outputType -eq "objectType")
            {
                $compResultValues = @()
            }

            foreach($compObj in @($compareObjectsResult | Where { $_.ObjectType.Id -eq $item.ObjectType.Id }))
            {
                $objName = Get-GraphObjectName (?? $compObj.Object1 $compObj.Object2) $item.ObjectType
                foreach($compValue in $compObj.Result)
                {
                    $compResultValues += [PSCustomObject]@{
                        ObjectName = $objName
                        Id = $compObj.Id
                        Type = $compObj.ObjectType.Title
                        ODataType = $compObj.Object1.'@OData.Type'
                        Property = $compValue.PropertyName
                        Value1 = $compValue.Object1Value
                        Value2 = $compValue.Object2Value
                        Category = $compValue.Category
                        SubCategory = $compValue.SubCategory
                        Match = $compValue.Match
                    }
                }
            }

            if($outputType -eq "objectType")
            {
                Save-BulkCompareResults $compResultValues (Join-Path $rootFolder "Compare_$(((Get-Date).ToString("yyyyMMdd-HHmm"))).csv") $compareProps
            }
        }
        else
        {
            Write-Log "Folder $folder not found. Skipping import" 2    
        }
    }

    if($outputType -eq "all" -and $compResultValues.Count -gt 0)
    {
        Save-BulkCompareResults $compResultValues (Join-Path $folder "Compare_$(((Get-Date).ToString("yyyyMMDD-HHmm"))).csv") $compareProps
    }    

    Write-Log "****************************************************************"
    Write-Log "Bulk compare Exported Objects finished"
    Write-Log "****************************************************************"
    Write-Status ""
    if($compareObjectsResult.Count -eq 0)
    {
        [System.Windows.MessageBox]::Show("No objects were comparced. Verify folder and exported files", "Error", "OK", "Error")
    }
}

function Save-BulkCompareResults
{
    param($compResultValues, $file, $props)

    if($compResultValues.Count -gt 0)
    {
        $params = @{}
        try
        {        
            if($global:cbCompareCSVDelimiter.Text)
            {
                $params.Add("Delimiter", [char]$global:cbCompareCSVDelimiter.Text)
            }
        }
        catch
        {
            
        }
        Write-Log "Save bulk comare results to $file"
        $compResultValues | Select -Property $props | ConvertTo-Csv -NoTypeInformation @params | Out-File -LiteralPath $file -Force -Encoding UTF8
    } 
}

function Show-CompareForm
{
    param($objInfo)

    $script:cmpForm = Get-XamlObject ($global:AppRootFolder + "\Xaml\CompareForm.xaml") -AddVariables
    if(-not $script:cmpForm) { return }

    $script:cmpForm.Tag = $objInfo

    $script:copareSource = $objInfo

    $global:cbCompareType.ItemsSource = $global:comparisonTypes | Where ShowOnObject -ne $false
    $global:cbCompareType.SelectedValue = (Get-Setting "Compare" "Type" "property")

    $global:txtIntuneObject.Text = (Get-GraphObjectName $objInfo.Object $objInfo.ObjectType)
    $global:txtIntuneObject.Tag = $objInfo

    Add-XamlEvent $script:cmpForm "btnClose" "add_click" {
        $script:cmpForm = $null
        Show-ModalObject 
    }

    Add-XamlEvent $script:cmpForm "btnStartCompare" "add_click" {
        Write-Status "Compare objects"
        Save-Setting "Compare" "Type" $global:cbCompareType.SelectedValue
        $script:currentObjName = ""
        Start-CompareExportObject
        Write-Status "" 
    }
    
    Add-XamlEvent $script:cmpForm "btnCompareSave" "add_click" {

        if(($global:dgCompareInfo.ItemsSource | measure).Count -eq 0) { return }

        $sf = [System.Windows.Forms.SaveFileDialog]::new()
        $sf.FileName = $script:currentObjName
        $sf.initialDirectory = (?: ($global:lastCompareFile -eq $null) (Get-Setting "" "LastUsedRoot") ([IO.FileInfo]$global:lastCompareFile).DirectoryName)
        $sf.DefaultExt = "*.csv"
        $sf.Filter = "CSV (*.csv)|*.csv|All files (*.*)| *.*"
        if($sf.ShowDialog() -eq "OK")
        {
            $csvInfo = Get-CompareCsvInfo $global:dgCompareInfo.ItemsSource $script:cmpForm.Tag
            $csvInfo | Out-File -LiteralPath $sf.FileName -Force -Encoding UTF8
        }    
    }

    Add-XamlEvent $script:cmpForm "btnCompareCopy" "add_click" {

        (Get-CompareCsvInfo $global:dgCompareInfo.ItemsSource $script:cmpForm.Tag) | Set-Clipboard
    }    

    Add-XamlEvent $script:cmpForm "browseCompareObject" "add_click" {

        $path = Get-Setting "" "LastUsedFullPath"
        if($path) 
        {
            $path = [IO.Directory]::GetParent($path).FullName
            if($global:txtIntuneObject.Tag.ObjectType)
            {
                $objectTypePath = [IO.Path]::Combine($path, $global:txtIntuneObject.Tag.ObjectType.Id)
                if([IO.Directory]::Exists($objectTypePath))
                {
                    $path = $objectTypePath
                }
            }
        }

        if([String]::IsNullOrEmpty($global:lastCompareFile) -eq $false)
        {
            $path = ([IO.FileInfo]$global:lastCompareFile).DirectoryName
        }

        $of = [System.Windows.Forms.OpenFileDialog]::new()
        $of.Multiselect = $false
        $of.Filter = "Json files (*.json)|*.json"
        if($path)
        {
            $of.InitialDirectory = $path
        }

        if($of.ShowDialog())
        {
            Set-XamlProperty $script:cmpForm "txtCompareFile" "Text" $of.FileName
            $global:lastCompareFile = $of.FileName
        }
    }

    #Add-XamlEvent $script:cmpForm "dgCompareInfo" "add_loaded" {

    #}

    Show-ModalForm "Compare Intune Objects" $script:cmpForm -HideButtons
}

function Get-CompareCsvInfo
{
    param($comareInfo, $objInfo)

    $compResultValues = @()
    $objName = Get-GraphObjectName $objInfo.Object $objInfo.ObjectType
    foreach($compValue in $comareInfo)
    {
        $compResultValues += [PSCustomObject]@{
            ObjectName = $objName
            Id =  $objInfo.Object.Id
            Type = $objInfo.ObjectType.Title
            ODataType = $objInfo.Object.'@OData.Type'
            Property = $compValue.PropertyName
            Value1 = $compValue.Object1Value
            Value2 = $compValue.Object2Value
            Category = $compValue.Category
            SubCategory = $compValue.SubCategory
            Match = $compValue.Match
        }
    }            

    $compareProps = $script:defaultCompareProps

    # !!! Not supported yet
    #foreach($removeProp in $global:cbCompareProvider.SelectedItem.RemoveProperties)
    #{
    #    $compareProps.Remove($removeProp) | Out-Null
    #}

    foreach($removeProp in $global:cbCompareType.SelectedItem.RemoveProperties)
    {
        $compareProps.Remove($removeProp) | Out-Null
    }
    $compResultValues | Select -Property $compareProps | ConvertTo-Csv -NoTypeInformation
}

function Start-CompareExportObject
{
    if(-not $script:copareSource) { return }

    if(-not $global:txtCompareFile.Text)
    {
        [System.Windows.MessageBox]::Show("No file selected", "Compare", "OK", "Error")
        return
    }
    elseif([IO.File]::Exists($global:txtCompareFile.Text) -eq $false)
    {
        [System.Windows.MessageBox]::Show("File '$($global:txtCompareFile.Text)' not found", "Compare", "OK", "Error")
        return
    }

    try
    {
        if($script:copareSource.ObjectType.LoadObject)
        {
            $compareObj  = & $script:copareSource.ObjectType.LoadObject $global:txtCompareFile.Text
        }
        else
        {
            $compareObj = Get-Content -LiteralPath $global:txtCompareFile.Text | ConvertFrom-Json 
        }
    }
    catch
    {
        [System.Windows.MessageBox]::Show("Failed to convert json file '$($global:txtCompareFile.Text)'", "Compare", "OK", "Error")
        return
    }

    $obj = Get-GraphObject $script:copareSource.Object $script:copareSource.ObjectType

    $script:currentObjName = Get-GraphObjectName $script:copareSource.Object $script:copareSource.ObjectType

    if($obj.Object."@OData.Type" -ne $compareObj."@OData.Type")
    {
        if(([System.Windows.MessageBox]::Show("The object types does not match.`n`nDo you to compare the objects?", "Compare", "YesNo", "Warning")) -eq "No")
        {
            return
        }
    }

    $compareObj | Add-Member Noteproperty -Name "@ObjectFromFile" -Value $true -Force

    $compareResult = Compare-Objects $obj.Object $compareObj $obj.ObjectType

    $global:dgCompareInfo.ItemsSource = $compareResult
}

function Compare-Objects
{
    param($obj1, $obj2, $objectType)

    $script:compareProperties = @()

    if($obj1.'@OData.Type' -eq "#microsoft.graph.deviceManagementConfigurationPolicy" -or 
        $obj1.'@OData.Type' -eq "#microsoft.graph.deviceManagementIntent" -or 
        $obj1.'@OData.Type' -eq "#microsoft.graph.groupPolicyConfiguration")
    {
        # Always use documentation for Settings Catalog, Endpoint Security and Administrative Template policies
        # These use Graph API for docummentation and all properties will be documented
        $compareResult = Compare-ObjectsBasedonDocumentation $obj1 $obj2 $objectType
    }
    elseif($global:cbCompareType.SelectedItem.Compare)
    {
        $compareResult = & $global:cbCompareType.SelectedItem.Compare $obj1 $obj2 $objectType
    }
    else
    {
        Write-Log "Selected comparison type ($($global:cbCompareType.SelectedItem.Name)) does not have a Compare property specified" 3
    }

    $compareResult
}

function Set-ColumnVisibility
{
    param($showCategory = $false, $showSubCategory = $false)

    $colTmp = $global:dgCompareInfo.Columns | Where { $_.Binding.Path.Path -eq "Category" }
    if($colTmp)
    {
        $colTmp.Visibility = (?: ($showCategory -eq $true) "Visible" "Collapsed")
    }

    $colTmp = $global:dgCompareInfo.Columns | Where { $_.Binding.Path.Path -eq "SubCategory" }
    if($colTmp)
    {
        $colTmp.Visibility = (?: ($showSubCategory -eq $true) "Visible" "Collapsed")
    }
}

function Add-CompareProperty
{
    param($name, $value1, $value2, $category, $subCategory, $match = $null)

    $value1 = if($value1 -eq $null) { "" } else { $value1.ToString().Trim("`"") }
    $value2 = if($value2 -eq $null) { "" } else {  $value2.ToString().Trim("`"") }

    $script:compareProperties += [PSCustomObject]@{
        PropertyName = $name
        Object1Value = $value1 #if($value1 -ne $null) { $value1.ToString().Trim("`"") } else { "" }
        Object2Value = $value2 #if($value2 -ne $null) { $value2.ToString().Trim("`"") } else { "" }
        Category = $category
        SubCategory = $subCategory
        Match = ?? $match ($value1 -eq $value2)
    }
}

function Compare-ObjectsBasedonProperty
{
    param($obj1, $obj2, $objectType)

    Write-Status "Compare objects based on property values"

    Set-ColumnVisibility $false

    $coreProps = @((?? $objectType.NameProperty "displayName"), "Description", "Id", "createdDateTime", "lastModifiedDateTime", "version")
    $postProps = @("Advertisements")

    foreach ($propName in $coreProps)
    {
        if(-not ($obj1.PSObject.Properties | Where Name -eq $propName))
        {
            continue
        }
        $val1 = ($obj1.$propName | ConvertTo-Json -Depth 10)
        $val2 = ($obj2.$propName | ConvertTo-Json -Depth 10)
        Add-CompareProperty $propName $val1 $val2
    }    

    $addedProps = @()
    foreach ($propName in ($obj1.PSObject.Properties | Select Name).Name) 
    {
        if($propName -in $coreProps) { continue }
        if($propName -in $postProps) { continue }

        if($propName -like "*@OData*" -or $propName -like "#microsoft.graph*") { continue }

        $addedProps += $propName
        $val1 = ($obj1.$propName | ConvertTo-Json -Depth 10)
        $val2 = ($obj2.$propName | ConvertTo-Json -Depth 10)
        Add-CompareProperty $propName $val1 $val2
    }

    foreach ($propName in ($obj2.PSObject.Properties | Select Name).Name) 
    {
        if($propName -in $coreProps) { continue }
        if($propName -in $postProps) { continue }
        if($propName -in $addedProps) { continue }

        if($propName -like "*@OData*" -or $propName -like "#microsoft.graph*") { continue }

        $val1 = ($obj1.$propName | ConvertTo-Json -Depth 10)
        $val2 = ($obj2.$propName | ConvertTo-Json -Depth 10)
        Add-CompareProperty $propName $val1 $val2
    }    

    foreach ($propName in $postProps)
    {
        if(-not ($obj1.PSObject.Properties | Where Name -eq $propName))
        {
            continue
        }
        $val1 = ($obj1.$propName | ConvertTo-Json -Depth 10)
        $val2 = ($obj2.$propName | ConvertTo-Json -Depth 10)
        Add-CompareProperty $propName $val1 $val2
    }
    
    $script:compareProperties
}

function Get-CompareCustomColumnsDoc
{
    param($obj)

    if($obj.'@OData.Type' -eq "#microsoft.graph.deviceEnrollmentPlatformRestrictionsConfiguration")
    {
        Set-ColumnVisibility $true $true
    }
    else
    {
        Set-ColumnVisibility $true $false
    }
}

function Compare-ObjectsBasedonDocumentation
{
    param($obj1, $obj2, $objectType)

    Write-Status "Compare objects based on documentation values"

    Get-CompareCustomColumnsDoc $obj1

    # ToDo: set this based on configuration value
    $script:assignmentOutput = "simpleFullCompare"

    $docObj1 = Invoke-ObjectDocumentation ([PSCustomObject]@{
        Object = $obj1
        ObjectType = $objectType
    })
    

    $docObj2 = Invoke-ObjectDocumentation ([PSCustomObject]@{
        Object = $obj2
        ObjectType = $objectType
    })

    $settingsValue = ?? $objectType.CompareValue "Value"

    if($docObj1.BasicInfo -and -not ($docObj1.BasicInfo | where Value -eq $obj1.Id))
    {
        # Make sure the Id property is included
        Add-CompareProperty "Id" $obj1.Id $obj2.Id $docObj1.BasicInfo[0].Category
    }

    foreach ($prop in $docObj1.BasicInfo)
    {
        $val1 = $prop.Value 
        $prop2 = $docObj2.BasicInfo | Where Name -eq $prop.Name
        $val2 = $prop2.Value 
        Add-CompareProperty $prop.Name $val1 $val2 $prop.Category
    }

    $addedProperties = @()

    if($docObj1.InputType -eq "Settings")
    {
        foreach ($prop in $docObj1.Settings)
        {
            if(($prop.SettingId + $prop.ParentSettingId) -in $addedProperties) { continue }

            $addedProperties += ($prop.SettingId + $prop.ParentSettingId)
            $val1 = $prop.Value 
            $prop2 = $docObj2.Settings | Where { $_.SettingId -eq $prop.SettingId -and $_.ParentSettingId -eq $prop.ParentSettingId }
            $val2 = $prop2.Value
            Add-CompareProperty $prop.Name $val1 $val2 $prop.Category

            # ToDo: fix lazy copy/past coding
            $children1 = $docObj1.Settings | Where ParentId -eq $prop.Id
            $children2 = $docObj2.Settings | Where ParentId -eq $prop2.Id
            
            # Add children defined on Object 1 property
            foreach ($childProp in $children1)
            {
                if(($childProp.SettingId + $childProp.ParentSettingId) -in $addedProperties) { continue }

                $addedProperties += ($childProp.SettingId + $childProp.ParentSettingId)
                $val1 = $childProp.Value 
                $prop2 = $docObj2.Settings | Where { $_.SettingId -eq $childProp.SettingId -and $_.ParentSettingId -eq $childProp.ParentSettingId }
                $val2 = $prop2.Value
                Add-CompareProperty $childProp.Name $val1 $val2 $prop.Category
            }
            
            # Add children defined only on Object 2 property e.g. Baseline Firewall profile was disable AFTER export.
            # This is to make sure all children are added under its parent and not last in the table
            foreach ($childProp in $children2)
            {
                if(($childProp.SettingId + $childProp.ParentSettingId) -in $addedProperties) { continue }

                $addedProperties += ($childProp.SettingId + $childProp.ParentSettingId)
                $val2 = $childProp.Value 
                $prop2 = $docObj1.Settings | Where { $_.SettingId -eq $childProp.SettingId -and $_.ParentSettingId -eq $childProp.ParentSettingId }
                $val1 = $prop2.Value
                Add-CompareProperty $childProp.Name $val1 $val2 $prop.Category
            }
        }
        
        # These objects are defined only on Object 2. They will be last in the table
        foreach ($prop in $docObj2.Settings)
        {
            if(($prop.SettingId + $prop.ParentSettingId) -in $addedProperties) { continue }

            $addedProperties += ($prop.SettingId + $prop.ParentSettingId)
            $val2 = $prop.Value    
            $prop2 = $docObj1.Settings | Where  { $_.SettingId -eq $prop.SettingId -and $_.ParentSettingId -eq $prop.ParentSettingId }
            $val1 = $prop2.Value   
            Add-CompareProperty $prop.Name $val1 $val2 $prop.Category
        }    
    }
    else
    {
        foreach ($prop in $docObj1.Settings)
        {
            if(($prop.EntityKey + $prop.Category + $prop.SubCategory) -in $addedProperties) { continue }

            $addedProperties += ($prop.EntityKey + $prop.Category + $prop.SubCategory)
            $val1 = $prop.$settingsValue 
            $prop2 = $docObj2.Settings | Where { $_.EntityKey -eq $prop.EntityKey -and $_.Category -eq $prop.Category -and $_.SubCategory -eq $prop.SubCategory -and $_.Enabled -eq $prop.Enabled }
            $val2 = $prop2.$settingsValue
            Add-CompareProperty $prop.Name $val1 $val2 $prop.Category $prop.SubCategory
        }
        
        # These objects are defined only on Object 2. They will be last in the table
        foreach ($prop in $docObj2.Settings)
        {
            if(($prop.EntityKey + $prop.Category + $prop.SubCategory) -in $addedProperties) { continue }

            $addedProperties += ($prop.EntityKey + $prop.Category + $prop.SubCategory)
            $val2 = $prop.$settingsValue
            $prop2 = $docObj1.Settings | Where  { $_.EntityKey -eq $prop.EntityKey -and $_.Category -eq $prop.Category -and $_.SubCategory -eq $prop.SubCategory -and $_.Enabled -eq $prop.Enabled  }
            $val1 = $prop2.$settingsValue   
            Add-CompareProperty $prop.Name $val1 $val2 $prop.Category $prop.SubCategory
        }           
    }

    $applicabilityRulesAdded = @()
    #$properties = @("Rule","Property","Value")
    foreach($applicabilityRule in $docObj1.ApplicabilityRules)
    {
        $applicabilityRule2 = $docObj2.ApplicabilityRules | Where { $_.Id -eq $applicabilityRule.Id }
        $applicabilityRulesAdded += $applicabilityRule.Id
        $val1 = ($applicabilityRule.Rule + [environment]::NewLine + $applicabilityRule.Value)
        $val2 = ($applicabilityRule2.Rule + [environment]::NewLine + $applicabilityRule2.Value)

        Add-CompareProperty $applicabilityRule.Property $val1 $val2 $applicabilityRule.Category
    }

    foreach($applicabilityRule in $docObj2.ApplicabilityRules)
    {
        if(($applicabilityRule.Id) -in $applicabilityRulesAdded) { continue }
        $applicabilityRule2 = $docObj1.ApplicabilityRules | Where { $_.Id -eq $applicabilityRule.Id }
        $script:applicabilityRulesAdded += $applicabilityRule.Id
        $val2 = ($applicabilityRule.Rule + [environment]::NewLine + $applicabilityRule.Value)
        $val1 = ($applicabilityRule2.Rule + [environment]::NewLine + $applicabilityRule2.Value)

        Add-CompareProperty $applicabilityRule.Property $val1 $val2 $applicabilityRule.Category
    }    

    $complianceActionsAdded = @()
    foreach($complianceAction in $docObj1.ComplianceActions)
    {
        $complianceAction2 = $docObj2.ComplianceActions | Where { $_.IdStr -eq $complianceAction.IdStr }
        $complianceActionsAdded += $complianceAction.IdStr
        $val1 = ($complianceAction.Action + [environment]::NewLine + $complianceAction.Schedule + [environment]::NewLine + $complianceAction.MessageTemplateId + [environment]::NewLine + $complianceAction.EmailCCIds)
        $val2 = ($complianceAction2.Action + [environment]::NewLine + $complianceAction2.Schedule + [environment]::NewLine + $complianceAction2.MessageTemplateId + [environment]::NewLine + $complianceAction2.EmailCCIds)

        Add-CompareProperty $complianceAction.Category $val1 $val2 
    }

    foreach($complianceAction in $docObj2.ComplianceActions)
    {
        if(($complianceAction.IdStr) -in $complianceActionsAdded) { continue }
        $complianceAction2 = $docObj1.ComplianceActions | Where { $_.IdStr -eq $complianceAction.IdStr }
        $complianceActionsAdded += $complianceAction.IdStr
        $val2 = ($complianceAction.Action + [environment]::NewLine + $complianceAction.Schedule + [environment]::NewLine + $complianceAction.MessageTemplateId + [environment]::NewLine + $complianceAction.EmailCCIds)
        $val1 = ($complianceAction2.Action + [environment]::NewLine + $complianceAction2.Schedule + [environment]::NewLine + $complianceAction2.MessageTemplateId + [environment]::NewLine + $complianceAction2.EmailCCIds)

        Add-CompareProperty $complianceAction.Category $val1 $val2 
    }

    $script:assignmentStr = Get-LanguageString "TableHeaders.assignment"
    $script:groupsAdded = @()

    $assignmentType = $null
    $curType = $null

    foreach ($assignment in $docObj1.Assignments)
    {
        #if(-not $assignmentType)
        #{
        #    $assignmentType = (?: ($assignment.RawIntent -eq $null) "generic" "app") 
        #}
        
        $prevType = $null

        if($curType -ne $assignment.Category) 
        {
            if($curType) { $prevType = $curType}
            $curType = $assignment.Category
        }

        if($prevType)
        {
            # Add any additional missing intent in the same intent group
            foreach($tmpAssignment in $docObj2.Assignments | Where { $_.Category -eq $prevType })
            {
                Add-AssignmentInfo $docObj2 $docObj1 $tmpAssignment -ReversedValue
            }
        }
        Add-AssignmentInfo $docObj1 $docObj2 $assignment
    }

    # Add any missing assignments from Object 2
    foreach ($assignment in $docObj2.Assignments)
    {
        Add-AssignmentInfo $docObj2 $docObj1 $assignment -ReversedValue
    }

    $script:compareProperties
}

function Add-AssignmentInfo
{
    param($srcObj, $cmpObj, $assignment, [switch]$ReversedValue)
 
    if(($assignment.Group + $assignment.GroupMode + $assignment.RawIntent) -in $script:groupsAdded) { continue }

    $assignment2 = $cmpObj.Assignments | Where { $_.GroupMode -eq $assignment.GroupMode -and $_.Group -eq $assignment.Group -and $_.RawIntent -eq $assignment.RawIntent }
    $script:groupsAdded += ($assignment.Group + $assignment.GroupMode + $assignment.RawIntent)

    $match = $null    

    # To only show the group name
    if($script:assignmentOutput -eq "simple")
    {
        $val1 = $assignment.Group
        $val2 = $assignment2.Group
    }
    else
    {
        # Show full Assignment info
        # -Property @("Group","*") will generete error but will put the Group first and the rest of the properties after it. ErrorAction SilentlyContinue will ignore the error
        # Should be another way of doing this without generating an error. 
        $val1 = $assignment | Select -Property @("Group","*") -ExcludeProperty @("RawJsonValue","RawIntent","GroupMode","Category") -ErrorAction SilentlyContinue | ConvertTo-Json -Compress #$assignment.Group
        $val2 = $assignment2 | Select -Property @("Group","*") -ExcludeProperty @("RawJsonValue","RawIntent","GroupMode","Category") -ErrorAction SilentlyContinue | ConvertTo-Json -Compress #$assignment2.Group
        
        if($script:assignmentOutput -eq "simpleFullCompare")
        {
            # Full compare but show only the Group name. This could cause red for not matching even though the same group is used e.g. Filter is changed
            $match = ($val1 -eq $val2)
            $val1 = $assignment.Group
            $val2 = $assignment2.Group    
        }
    }

    if($ReversedValue -eq $true)
    {
        $tmpVal = $val1
        $val1 = $val2
        $val2 = $tmpVal
    }

    if($assignment.RawIntent)
    {
        Add-CompareProperty $assignment.Category $val1 $val2 -Category $assignment.GroupMode -match $match
    }
    else
    {
        Add-CompareProperty $assignmentStr $val1 $val2 -Category $assignment.GroupMode -match $match
    }
}