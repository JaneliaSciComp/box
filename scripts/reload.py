#!/bin/env python
import MySQLdb as sql
import argparse
import os

#connect db
def connect_db():
    db = sql.connect(host='mysql3', user='sageApp', passwd='h3ll0K1tty', db='sage')
    c = db.cursor()
    return c, db

def run_program(c, exp):
    enames = []
    for ex in exp:
	    enames.append(ex)
    """
        if ex.isdigit():
            c.execute("select name from experiment where id = %s" % (ex))
            result = c.fetchone()
            enames.append(result[0])
            e = ex
        else: 
            enames.append(ex)
            c.execute("select id from experiment where name = '%s'" % (ex))
            result = c.fetchone()
            e = result[0]
        c.execute("select id from session where experiment_id = %s" % (e))
        result = c.fetchall()
        sessions = ""
        for i in result:
            sessions += str(i[0]) + ","
        c.execute("delete from score_array where session_id in (%s) or experiment_id = %s" % (sessions[:-1], e))
        c.execute("delete from experiment where id = %s" % (e))
    """
    print "DELETED"
    rm_file(enames)
    mv_file(enames)
    for name in enames:
        print name

def mv_file(enames):
    mvfi = open("mv_me_auto.sh", "w")
    mvfi.write("#!/bin/sh\n")
    for name in enames:
        mvfi.write("mv %s ../00_incoming\n" % (name))
    mvfi.close()
    os.chmod('mv_me_auto.sh', 0775)

def rm_file(enames):
    rmfi = open("rm_me_auto.sh", "w")
    rmfi.write("#!/bin/sh\n")
    for name in enames:
        rmfi.write("rm %s/01_4.1_34/*tube*\n" % (name))
        rmfi.write("rm %s/01_4.1_34/6\n" % (name))
        rmfi.write("rm -rf %s/Output*\n" % (name))
    rmfi.close()
    os.chmod('rm_me_auto.sh', 0775)
def get_experiments(e):
    fi = open(e, 'rb');
    data = fi.readlines()
    data = [x.rstrip() for x in data]
    fi.close()
    print data
    return data
    
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Load Mad Data")
    parser.add_argument('--debug', dest='debug', action='store_true', default=False, help='Flag, verbose output if set')
    parser.add_argument('--insert', dest='insert', action='store_true', default=False, help='Flag, commits to database is set')
    parser.add_argument('--experiments', dest='experiment',  default=False, help='Flag, file with list of experiments')
    args = parser.parse_args()
    
    debug = args.debug
    insert = args.insert
    exp = args.experiment
    exp = get_experiments(exp)    

    cursor, db = connect_db()
    run_program(cursor, exp)
    
    if (insert):
        db.commit()
    else:
        db.rollback()
