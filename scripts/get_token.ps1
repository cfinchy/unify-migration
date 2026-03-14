# Retrieves HA long-lived token from Windows Credential Manager
# Usage: $token = . .\scripts\get_token.ps1

Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public class CM {
    [DllImport("Advapi32.dll",EntryPoint="CredReadW",CharSet=CharSet.Unicode,SetLastError=true)]
    public static extern bool CredRead(string t,uint tp,uint f,out IntPtr c);
    [DllImport("Advapi32.dll")] public static extern void CredFree(IntPtr c);
    [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]
    public struct CRED{public uint F,T;public string TN,C;public long LW;public uint CBS;public IntPtr CB;public uint P,AC;public IntPtr A;public string TA,UN;}
    public static string Get(string target){IntPtr p;if(!CredRead(target,1,0,out p))return null;var c=(CRED)Marshal.PtrToStructure(p,typeof(CRED));var pw=Marshal.PtrToStringUni(c.CB,(int)c.CBS/2);CredFree(p);return pw;}
}
'@ -ErrorAction SilentlyContinue

$token = [CM]::Get("HomeAssistant")
if (-not $token) { Write-Error "Token not found in Credential Manager. Run: cmdkey /generic:HomeAssistant /user:ha_api /pass:<token>"; exit 1 }
Write-Host "Token retrieved (length $($token.Length))"
return $token
