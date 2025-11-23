#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/stat.h>

#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <paths.h>
#include <pwd.h>
#include <stdarg.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <stdarg.h>
// #include <util.h>

// #include "sshpty.h"
// #include "log.h"

#include <stdio.h>
#include <pty.h>
#include <stdlib.h>

// void error(char *format, args...) {
//   strcat(format, "\n");
//   printf(format, args...);
// }

// void

#ifndef O_NOCTTY
#define O_NOCTTY 0
#endif

/*
 * Allocates and opens a pty.  Returns 0 if no pty could be allocated, or
 * nonzero if a pty was successfully allocated.  On success, open file
 * descriptors for the pty and tty sides and the name of the tty side are
 * returned (the buffer must be able to hold at least 64 characters).
 */

int
pty_allocate(int *ptyfd, int *ttyfd, char *namebuf, size_t namebuflen)
{
	char buf[64];
	int i;

	i = openpty(ptyfd, ttyfd, buf, NULL, NULL);
	if (i < 0) {
	  printf("openpty: %.100s\n", strerror(errno));
		return 0;
	}
	strlcpy(namebuf, buf, namebuflen);	/* possible truncation */
	return 1;
}

/* Releases the tty.  Its ownership is returned to root, and permissions to 0666. */

void
pty_release(const char *tty)
{
	if (chown(tty, (uid_t) 0, (gid_t) 0) < 0)
	  printf("chown %.100s 0 0 failed: %.100s\n", tty, strerror(errno));
	if (chmod(tty, (mode_t) 0666) < 0)
	  printf("chmod %.100s 0666 failed: %.100s\n", tty, strerror(errno));
}

/* Makes the tty the process's controlling tty and sets it to sane modes. */

void
pty_make_controlling_tty(int *ttyfd, const char *tty)
{
	int fd;

	/* First disconnect from the old controlling tty. */
#ifdef TIOCNOTTY
	fd = open(_PATH_TTY, O_RDWR | O_NOCTTY);
	if (fd >= 0) {
		(void) ioctl(fd, TIOCNOTTY, NULL);
		close(fd);
	}
#endif /* TIOCNOTTY */
	if (setsid() < 0)
	  printf("setsid: %.100s\n", strerror(errno));

	/*
	 * Verify that we are successfully disconnected from the controlling
	 * tty.
	 */
	fd = open(_PATH_TTY, O_RDWR | O_NOCTTY);
	if (fd >= 0) {
	  printf("Failed to disconnect from controlling tty.");
		close(fd);
	}
	/* Make it our controlling tty. */
#ifdef TIOCSCTTY
	printf("Setting controlling tty using TIOCSCTTY.\n");
	if (ioctl(*ttyfd, TIOCSCTTY, NULL) < 0)
	  printf("ioctl(TIOCSCTTY): %.100s\n", strerror(errno));
#endif /* TIOCSCTTY */
	fd = open(tty, O_RDWR);
	if (fd < 0)
	  printf("%.100s: %.100s\n", tty, strerror(errno));
	else
		close(fd);

	/* Verify that we now have a controlling tty. */
	fd = open(_PATH_TTY, O_WRONLY);
	if (fd < 0)
	  printf("open /dev/tty failed - could not set controlling tty: %.100s\n",
		    strerror(errno));
	else
		close(fd);
}

/* Changes the window size associated with the pty. */

void
pty_change_window_size(int ptyfd, u_int row, u_int col,
	u_int xpixel, u_int ypixel)
{
	struct winsize w;

	/* may truncate u_int -> u_short */
	w.ws_row = row;
	w.ws_col = col;
	w.ws_xpixel = xpixel;
	w.ws_ypixel = ypixel;
	(void) ioctl(ptyfd, TIOCSWINSZ, &w);
}

// void
// pty_setowner(struct passwd *pw, const char *tty)
// {
// 	struct group *grp;
// 	gid_t gid;
// 	mode_t mode;
// 	struct stat st;

// 	/* Determine the group to make the owner of the tty. */
// 	grp = getgrnam("tty");
// 	if (grp) {
// 		gid = grp->gr_gid;
// 		mode = S_IRUSR | S_IWUSR | S_IWGRP;
// 	} else {
// 		gid = pw->pw_gid;
// 		mode = S_IRUSR | S_IWUSR | S_IWGRP | S_IWOTH;
// 	}

// 	/*
// 	 * Change owner and mode of the tty as required.
// 	 * Warn but continue if filesystem is read-only and the uids match/
// 	 * tty is owned by root.
// 	 */
// 	if (stat(tty, &st))
// 		fatal("stat(%.100s) failed: %.100s\n", tty,
// 		    strerror(errno));

// 	if (st.st_uid != pw->pw_uid || st.st_gid != gid) {
// 		if (chown(tty, pw->pw_uid, gid) < 0) {
// 			if (errno == EROFS &&
// 			    (st.st_uid == pw->pw_uid || st.st_uid == 0))
// 				debug("chown(%.100s, %u, %u) failed: %.100s\n",
// 				    tty, (u_int)pw->pw_uid, (u_int)gid,
// 				    strerror(errno));
// 			else
// 				fatal("chown(%.100s, %u, %u) failed: %.100s\n",
// 				    tty, (u_int)pw->pw_uid, (u_int)gid,
// 				    strerror(errno));
// 		}
// 	}

// 	if ((st.st_mode & (S_IRWXU|S_IRWXG|S_IRWXO)) != mode) {
// 		if (chmod(tty, mode) < 0) {
// 			if (errno == EROFS &&
// 			    (st.st_mode & (S_IRGRP | S_IROTH)) == 0)
// 				debug("chmod(%.100s, 0%o) failed: %.100s\n",
// 				    tty, (u_int)mode, strerror(errno));
// 			else
// 				fatal("chmod(%.100s, 0%o) failed: %.100s\n",
// 				    tty, (u_int)mode, strerror(errno));
// 		}
// 	}
// }

/* Open/create the file named in 'pidFile', lock it, optionally set the
   close-on-exec flag for the file descriptor, write our PID into the file,
   and (in case the caller is interested) return the file descriptor
   referring to the locked file. The caller is responsible for deleting
   'pidFile' file (just) before process termination. 'progName' should be the
   name of the calling program (i.e., argv[0] or similar), and is used only for
   diagnostic messages. If we can't open 'pidFile', or we encounter some other
   error, then we print an appropriate diagnostic and terminate. */

int
create_pid_file(const char *progName, const char *pidFile, int flags)
{
    int fd;
    char buf[100];

    fd = open(pidFile, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
    if (fd == -1)
        printf("Could not open PID file %s\n", pidFile);

    snprintf(buf, 100, "%ld\n", (long) getpid());
    if (write(fd, buf, strlen(buf)) != (ssize_t) strlen(buf))
        printf("Writing to PID file '%s'\n", pidFile);

    return fd;
}

int main(void) {
  int fdpty, fdtty;
  const int namebuflen = 100;
  char namebuf[namebuflen];

  int s = pty_allocate(&fdpty, &fdtty, namebuf, namebuflen);
  printf("success: %d, fdpty: %d, fdtty: %d, namebuf: %s\n", s, fdpty, fdtty, namebuf);

	if (s == 0) return 1;

	struct termios term;
	struct winsize win;

	int pid = forkpty(&fdtty, namebuf, &term, &win);
	if (pid == -1) {
		printf("Error creating pseudo-terminal\n");
		return 1;
	}

	if (pid == 0) {
		printf("Initializing the shell...\n");

		int res = create_pid_file(namebuf, ".pid", 0);

		if (res > 0) {
			return res;
		}

		execlp(getenv("SHELL"), getenv("SHELL"), NULL);

		printf("execlp\n");
		exit(1);
	}

	return 0;
}
