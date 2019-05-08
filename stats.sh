gcc -Ofast -march=native -mfpmath=both -funroll-loops -floop-block -floop-interchange -floop-strip-mine -ftree-loop-distribution -fgraphite-identity -floop-nest-optimize -malign-data=cacheline -mtls-dialect=gnu2 -o /tmp/stats -xc - <<HEREDOC && exec /tmp/stats
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <dirent.h>
char *getfile(char *filename, char *buffer) {
	FILE *fp;
	if ((fp = fopen(filename, "r"))) {
		int size = fread(buffer, 1, 3000, fp);
		fclose(fp);
		buffer[size] = '\0';
		return buffer;
	} else {
		return 0;
	}
}
void main(void) {
	char buffer[3000], *file;
	for (;;) {
		file = getfile("/proc/version", buffer);
		file = file+14;
		*strchr(file, ' ') = '\0';
		char uname[30];
		sprintf(uname, "%s%s", "Linux ", file);

		file = getfile("/proc/uptime", buffer);
		*strchr(file, '.') = '\0';
		int days = atoll(file)/86400;
		int hours = atoll(file)/3600%24;
		int minutes = atoll(file)/60%60;
		char uptime[20];
		if (days > 0) {
			sprintf(uptime, "%dd %dh %dm", days, hours, minutes);
		} else if (hours > 0) {
			sprintf(uptime, "%dh %dm", hours, minutes);
		} else {
			sprintf(uptime, "%dm", minutes);
		}

		int processesi = 0;
		struct dirent *dir;
		DIR *dp = opendir("/proc/");
		while ((dir = readdir(dp)) != NULL) {
			if (dir->d_name[0] >= '0' && dir->d_name[0] <= '9') {
				processesi++;
			}
		}
		closedir(dp);
		char processes[10];
		sprintf(processes, "%d", processesi);

		file = getfile("/proc/stat", buffer);
		file = strstr(file, "procs_running ")+14;
		*strchr(file, '\n') = '\0';
		char active[5];
		strcpy(active, file);

		file = getfile("/proc/stat", buffer);
		*strchr(file, '\n') = '\0';
		file = file+3;
		unsigned long long int cputotal = 0, cpuidle = 0, cpulasttotal, cpulastidle;
		cputotal += atoll(strtok(file, " "));
		for (int i = 0; i < 2; i++, cputotal += atoll(strtok(NULL, " ")));
		char *cputoken = strtok(NULL, " ");
		cpuidle += atoll(cputoken);
		cputotal += atoll(cputoken);
		for (int i = 0; i < 6; i++, cputotal += atoll(strtok(NULL, " ")));
		char cpu[20];
		if (cputotal-cpulasttotal != 0) {
			sprintf(cpu, "%llu%%", (1000*((cputotal-cpulasttotal)-(cpuidle-cpulastidle))/(cputotal-cpulasttotal)+5)/10);
		}
		cpulasttotal = cputotal;
		cpulastidle = cpuidle;

		file = getfile("/proc/meminfo", buffer);
		char memory[50];
		strncpy(memory, strstr(file, "MemTotal: ")+10, 50); *strstr(memory, " kB") = '\0'; *strrchr(memory, ' ')+1;
		unsigned long long int memtotal = atoll(memory);
		strncpy(memory, strstr(file, "MemFree: ")+9, 50); *strstr(memory, " kB") = '\0'; *strrchr(memory, ' ')+1;
		unsigned long long int memfree = atoll(memory);
		strncpy(memory, strstr(file, "Buffers: ")+9, 50); *strstr(memory, " kB") = '\0'; *strrchr(memory, ' ')+1;
		unsigned long long int buffers = atoll(memory);
		strncpy(memory, strstr(file, "Cached: ")+8, 50); *strstr(memory, " kB") = '\0'; *strrchr(memory, ' ')+1;
		unsigned long long int cached = atoll(memory);
		strncpy(memory, strstr(file, "Shmem: ")+7, 50); *strstr(memory, " kB") = '\0'; *strrchr(memory, ' ')+1;
		unsigned long long int shmem = atoll(memory);
		strncpy(memory, strstr(file, "SReclaimable: ")+14, 50); *strstr(memory, " kB") = '\0'; *strrchr(memory, ' ')+1;
		unsigned long long int sreclaimable = atoll(memory);
		sprintf(memory, "%lluMiB %lluMiB %.0f%%", (memtotal+shmem-memfree-buffers-cached-sreclaimable)/1024, memtotal/1024, (float)(memtotal+shmem-memfree-buffers-cached-sreclaimable)/memtotal*100);

		file = getfile("/proc/net/dev", buffer);
		file = strchr(file, '\n')+1;
		file = strchr(file, '\n')+1;
		int x;
		for (int i = x = 1; file[i]; ++i) {
			if (file[i] != ' ' || file[i-1] != ' ') {
				file[x++] = file[i];
			}
		}
		file[x] = '\0';
		unsigned long long int totalint = 0, totaloutt = 0, totallastint, totallastoutt;
		char *token;
		token = strtok(file, "\n");
		while (token != NULL) {
			token = strchr(token, ':')+1;
			token = token+1;
			char *buf;
			strtok_r(token, " ", &buf);
			totalint += atoll(token);
			for (int i = 0; i < 8; i++, token = strtok_r(NULL, " ", &buf));
			totaloutt += atoll(token);
			token = strtok(NULL, "\n");
		}
		char totalin[20], totalout[20];
		sprintf(totalin, "%lluMiB", totalint/1048576);
		sprintf(totalout, "%lluMiB", totaloutt/1048576);
		char netin[20], netout[20];
		if (totalint-totallastint >= 104858) {
			sprintf(netin, "%.1fMiB/s", (float)(totalint-totallastint)/1048576/2);
		} else {
			sprintf(netin, "0MiB/s");
		}
		if (totaloutt-totallastoutt >= 104858) {
			sprintf(netout, "%.1fMiB/s", (float)(totaloutt-totallastoutt)/1048576/2);
		} else {
			sprintf(netout, "0MiB/s");
		}
		totallastint = totalint;
		totallastoutt = totaloutt;

		char tempfilename[40];
		for (int i = 0; i < 5; i++) {
			sprintf(tempfilename, "%s%d%s", "/sys/class/hwmon/hwmon", i, "/name");
			file = getfile(tempfilename, buffer);
			if (!file) {
				break;
			}
			*strchr(file, '\n') = '\0';
			if (strcmp(file, "coretemp") == 0 || strcmp(file, "nct6775") == 0 || strncmp(file, "it87", 4) == 0 || strcmp(file, "k8temp") == 0 || strcmp(file, "k9temp") == 0 ) {
				break;
			}
		}
		tempfilename[strlen(tempfilename)-4] = '\0';
		strcat(tempfilename, "temp1_input");
		file = getfile(tempfilename, buffer);
		if (!file) {
			tempfilename[strlen(tempfilename)-11] = '\0';
			strcat(tempfilename, "temp2_input");
			file = getfile(tempfilename, buffer);
		}
		char temperature[5];
		if (file) {
			file[strlen(file)-4] = 'C';
			file[strlen(file)-3] = '\0';
			strcpy(temperature, file);
		} else {
			strcpy(temperature, "N/A");
		}

		sprintf(buffer, "%ld", (time_t)time(NULL));
		char volume[5];
		if (atoll(buffer)%60 == 0 || volume[0] == '\0') {
			char soundfilename[50];
			sprintf(soundfilename, "%s%s%s", "/home/", getenv("USER"), "/.asoundrc");
			file = getfile(soundfilename, buffer);
			if (file) {
				file = strstr(file, "defaults.pcm.card ");
				if (file != NULL) {
					file = file+18;
					*strchr(file, '\n') = '\0';
				}
			}
			if (file) {
				sprintf(soundfilename, "%s%s%s", "/proc/asound/card", file, "/codec#0");
			} else {
				strcpy(soundfilename, "/proc/asound/card0/codec#0");
			}
			strcpy(volume, "N/A");
			file = getfile(soundfilename, buffer);
			if (file) {
				file = strstr(file, "Amp-Out vals:  [0x");
				if (file != NULL) {
					file = file+18;
					*strchr(file, ' ') = '\0';
					sprintf(volume, "%lu%%", strtol(file, NULL, 16));
				}
			}
		}

		file = getfile("/sys/class/power_supply/AC/online", buffer);
		char ac[2];
		if (file) {
			file[strlen(file)-1] = '\0';
			if (strcmp(file, "1") == 0) {
				ac[0] = 'Y';
			} else {
				ac[0] = 'N';
			}
		} else {
			ac[0] = 'Y';
		}
		ac[1] = '\0';

		file = getfile("/sys/class/power_supply/BAT0/capacity", buffer);
		if (!file) {
			file = getfile("/sys/class/power_supply/BAT1/capacity", buffer);
		}
		char battery[10];
		if (file) {
			*strchr(file, '\n') = '\0';
			strcat(file, "%");
			strcpy(battery, file);
		} else {
			strcpy(battery, "N/A");
		}

		char brightness[5];
		dp = opendir("/sys/class/backlight/");
		if (dp) {
			char brightnessfilename[70];
			char brightnessmaxfilename[70];
			while ((dir = readdir(dp)) != NULL) {
				sprintf(brightnessmaxfilename, "%s%s%s", "/sys/class/backlight/", dir->d_name, "/max_brightness");
				sprintf(brightnessfilename, "%s%s%s", "/sys/class/backlight/", dir->d_name, "/actual_brightness");
			}
			closedir(dp);
			if (strstr(brightnessfilename, "..") == NULL) {
				sprintf(brightness, "%d%s", atoi(getfile(brightnessfilename, buffer))*100/atoi(getfile(brightnessmaxfilename, buffer)), "%");
			} else {
				strcpy(brightness, "N/A");
			}
		} else {
			strcpy(brightness, "N/A");
		}

		file = getfile("/proc/net/wireless", buffer);
		char wifi[5];
		if (file) {
			file = strchr(file, '\n')+1;
			file = strchr(file, '\n')+1;
			if (*file) {
				strtok(file, " ");
				for (int i = 0; i < 2; i++, file = strtok(NULL, " "));
				file[strlen(file)-1] = '\0';
				sprintf(wifi, "%d%%", atoi(file)*100/70);
			} else {
				strcpy(wifi, "N/A");
			}
		} else {
			strcpy(wifi, "N/A");
		}

		time_t rawtime = time(NULL);
		struct tm *info = localtime(&rawtime);
		char date[40];
		strftime(date, 40, "%a %d %b %Y %H:%M:%S %Z", info);

		printf("\e[?25l\e[37m%s Up: \e[32m%s\e[37m Proc: \e[32m%s\e[37m Active: \e[32m%s\e[37m Cpu: \e[32m%s\e[37m Mem: \e[32m%s\e[37m Net In: \e[32m%s (%s)\e[37m Net Out: \e[32m%s (%s)\e[37m Temp: \e[32m%s\e[37m Volume: \e[32m%s\e[37m AC: \e[32m%s\e[37m Battery: \e[32m%s\e[37m Brightness: \e[32m%s\e[37m Wifi: \e[32m%s\e[37m %s             \e[0m\r", uname, uptime, processes, active, cpu, memory, netin, totalin, netout, totalout, temperature, volume, ac, battery, brightness, wifi, date);
		fflush(stdout);
		nanosleep((struct timespec[]){{2, 0}}, NULL);
	}
}
HEREDOC
