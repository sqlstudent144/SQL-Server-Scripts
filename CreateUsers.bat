REM This bat file will create a couple of groups and users to use for testing.
REM Note: The passwords are all the same so you should either change them
REM or only use this on throwaway/test servers/VMs.

REM https://sqlstudies.com/2015/05/20/adding-new-users-groups-in-windows/

NET LOCALGROUP "SevenDwarfs" /ADD

NET USER "Grumpy"	"slkjISJW*#&51s" /ADD
NET USER "Happy"	"slkjISJW*#&51s" /ADD
NET USER "Sleepy"	"slkjISJW*#&51s" /ADD
NET USER "Bashful"	"slkjISJW*#&51s" /ADD
NET USER "Sneezy"	"slkjISJW*#&51s" /ADD
NET USER "Dopey"	"slkjISJW*#&51s" /ADD
NET USER "Doc"		"slkjISJW*#&51s" /ADD
NET LOCALGROUP "SevenDwarfs" "Grumpy" /ADD
NET LOCALGROUP "SevenDwarfs" "Happy" /ADD
NET LOCALGROUP "SevenDwarfs" "Sleepy" /ADD
NET LOCALGROUP "SevenDwarfs" "Bashful" /ADD
NET LOCALGROUP "SevenDwarfs" "Sneezy" /ADD
NET LOCALGROUP "SevenDwarfs" "Dopey" /ADD
NET LOCALGROUP "SevenDwarfs" "Doc" /ADD


NET LOCALGROUP "Planets" /ADD

NET USER "Mercury"	 "slkjISJW*#&51s" /ADD
NET USER "Venus"	 "slkjISJW*#&51s" /ADD
NET USER "Earth"	 "slkjISJW*#&51s" /ADD
NET USER "Mars"		 "slkjISJW*#&51s" /ADD
NET USER "Ceres"	 "slkjISJW*#&51s" /ADD
NET USER "Jupiter"	 "slkjISJW*#&51s" /ADD
NET USER "Saturn"	 "slkjISJW*#&51s" /ADD
NET USER "Uranus"	 "slkjISJW*#&51s" /ADD
NET USER "Neptune"	 "slkjISJW*#&51s" /ADD
NET USER "Pluto"	 "slkjISJW*#&51s" /ADD
NET USER "Charon"	 "slkjISJW*#&51s" /ADD
NET USER "2003 UB313" "slkjISJW*#&51s" /ADD
NET LOCALGROUP "Mercury"	 "Planets" /ADD
NET LOCALGROUP "Venus"		 "Planets" /ADD
NET LOCALGROUP "Earth"		 "Planets" /ADD
NET LOCALGROUP "Mars"		 "Planets" /ADD
NET LOCALGROUP "Ceres"		 "Planets" /ADD
NET LOCALGROUP "Jupiter"	 "Planets" /ADD
NET LOCALGROUP "Saturn"		 "Planets" /ADD
NET LOCALGROUP "Uranus"		 "Planets" /ADD
NET LOCALGROUP "Neptune"	 "Planets" /ADD
NET LOCALGROUP "Pluto"		 "Planets" /ADD
NET LOCALGROUP "Charon"		 "Planets" /ADD
NET LOCALGROUP "2003 UB313"	 "Planets" /ADD
