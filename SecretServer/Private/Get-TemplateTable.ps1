#Return a hash table of Key=TemplateID Value=TemplateName pairs
function Get-TemplateTable {

    $TemplateTable = @{}
    
    Get-SSTemplate | ForEach-Object {
        $TemplateTable.Add($_.ID, $_.Name)
    }

    $TemplateTable
}