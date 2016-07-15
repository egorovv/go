// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// This program can be used as go_android_GOARCH_exec by the Go tool.
// It executes binaries on an android device using adb.
package main

import (
	"bytes"
	"flag"
	"fmt"
	"go/build"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/pkg/sftp"
	"golang.org/x/crypto/ssh"
)

var config struct {
	esx      string
	user     string
	password string
	ssh      *ssh.ClientConfig
	subdir   string
	rootdir  string
	testdir  string
	remote   string
	keep     bool
	mem      int
}

func sshInteractive(user, instruction string, questions []string, echos []bool) (answers []string, err error) {
	answers = []string{}
	err = nil

	for _, _ = range questions {
		answers = append(answers, config.password)
	}
	return
}

func getConfig() {

	flag.StringVar(&config.esx, "esx", "", "esx host")
	flag.StringVar(&config.user, "user", "root", "ssh user")
	flag.StringVar(&config.password, "passwd", "", "ssh password")
	flag.StringVar(&config.rootdir, "root", "/tmp", "root directory on the target")
	flag.BoolVar(&config.keep, "keep", false, "keep exec file on target")
	flag.IntVar(&config.mem, "mem", 0, "memory reservation")

	args := strings.Split(os.Getenv(`ESX`), ` `)

	flag.CommandLine.Parse(args)

	config.ssh = &ssh.ClientConfig{
		User: config.user,
		Auth: []ssh.AuthMethod{
			ssh.Password(config.password),
			ssh.KeyboardInteractive(sshInteractive),
		},
	}

	idRsaBuf, err := ioutil.ReadFile(os.Getenv("HOME") + "/.ssh/id_rsa")
	var idRsa ssh.Signer
	if err == nil {
		idRsa, err = ssh.ParsePrivateKey(idRsaBuf)
	}

	if err == nil {
		config.ssh.Auth = append(config.ssh.Auth, ssh.PublicKeys(idRsa))
	}

	subdir, _ := subdir()
	config.testdir = filepath.Join(config.rootdir, subdir)
	_, file := filepath.Split(os.Args[1])
	config.remote = strings.Replace(
		filepath.Join(
			strings.TrimPrefix(subdir, `src/`), file),
		"/", "_", -1)
}

func put(sftp *sftp.Client, local, remote string) {
	stat, err := os.Stat(local)
	if err != nil {
		log.Fatal(err)
	}

	buf, err := ioutil.ReadFile(local)
	if err != nil {
		log.Fatal(err)
	}

	f, err := sftp.Create(remote)
	if err != nil {
		log.Fatal(err)
	}

	if _, err := f.Write(buf); err != nil {
		log.Fatal(err)
	}

	err = sftp.Chmod(remote, stat.Mode())
}

func putdir(sftp *sftp.Client, local, remote string) {
	if fi, err := os.Stat(local); err != nil || !fi.IsDir() {
		return
	}

	parts := strings.Split(remote, "/")
	for i := 2; i <= len(parts); i++ {
		dir := "/" + filepath.Join(parts[:i]...)
		_, err := sftp.Stat(dir)
		if err != nil {
			err = sftp.Mkdir(dir)
		}
		if err != nil {
			log.Panic(err)
		}
	}

	filepath.Walk(local,
		func(file string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			if info.Mode().IsDir() {
				_, err := sftp.Stat(config.testdir + "/" + file)
				if err != nil {
					err = sftp.Mkdir(remote + "/" + file)
				}
				if err != nil {
					log.Panic(err)
				}
			} else if info.Mode().IsRegular() {
				put(sftp, file, config.testdir+"/"+file)
			}
			return nil
		})
}

func remove(c *ssh.Client, remote string) {

	sftp, err := sftp.NewClient(c)
	if err != nil {
		log.Fatal(err)
	}
	defer sftp.Close()

	sftp.Remove(remote)

}

func run(c *ssh.Client, prog string, args ...string) error {
	session, err := c.NewSession()
	if err != nil {
		panic("Failed to create session: " + err.Error())
	}
	defer session.Close()

	var b bytes.Buffer
	session.Stdout = &b
	session.Stderr = &b

	rp := ""
	if config.mem != 0 {
		rp = fmt.Sprintf("/usr/lib/vmware/rp/bin/runInRP --max %d ",
			config.mem)
	}
	fmt.Println(b.String())
	cmd := fmt.Sprintf("mkdir -p %s && cd %s && %s%s ",
		config.testdir, config.testdir, rp, prog) +
		strings.Join(args, ` `)
	err = session.Run(cmd)
	fmt.Println(b.String())
	return err
}

func main() {
	log.SetFlags(0)
	log.SetPrefix("go_esx_exec: ")

	getConfig()

	esxHostPort := fmt.Sprintf("%s:22", config.esx)

	client, err := ssh.Dial("tcp", esxHostPort, config.ssh)
	if err != nil {
		panic("Failed to dial: " + err.Error())
	}

	sftp, err := sftp.NewClient(client)
	if err != nil {
		log.Fatal(err)
	}
	defer sftp.Close()

	remote := filepath.Join(config.rootdir, config.remote)

	put(sftp, os.Args[1], remote)
	putdir(sftp, "testdata", config.testdir)

	err = run(client, remote, os.Args[2:]...)

	if !config.keep && err == nil {
		remove(client, remote)
	}

	if err != nil {
		os.Exit(1)
	}
}

// subdir determines the package based on the current working directory,
// and returns the path to the package source relative to $GOROOT (or $GOPATH).
func subdir() (pkgpath string, underGoRoot bool) {
	cwd, err := os.Getwd()
	if err != nil {
		log.Fatal(err)
	}
	if root := runtime.GOROOT(); strings.HasPrefix(cwd, root) {
		subdir, err := filepath.Rel(root, cwd)
		if err != nil {
			log.Fatal(err)
		}
		return subdir, true
	}

	for _, p := range filepath.SplitList(build.Default.GOPATH) {
		if !strings.HasPrefix(cwd, p) {
			continue
		}
		subdir, err := filepath.Rel(p, cwd)
		if err == nil {
			return subdir, false
		}
	}
	log.Fatalf("the current path %q is not in either GOROOT(%q) or GOPATH(%q)",
		cwd, runtime.GOROOT(), build.Default.GOPATH)
	return "", false
}
