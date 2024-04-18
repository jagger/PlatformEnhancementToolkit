# class to hold PlatformConnections
class PlatformConnection
{
    [System.String]$Url
    [PSCustomObject]$PlatformConnection
    [System.Collections.Hashtable]$PlatformSessionInformation

    PlatformConnection($u,$ssc,$ss)
    {
        $this.Url = $u
        $this.PlatformConnection = $ssc
        $this.PlatformSessionInformation = $ss
    }
}# class PlatformConnection