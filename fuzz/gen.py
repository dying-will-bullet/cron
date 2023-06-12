#!/bin/python3

import random
from typing import List, Tuple
from crontab import CronTab
from datetime import datetime

now = datetime.now()


class RandomCron:
    def __init__(self):
        self.cron = [
            self.minute(),
            self.hour(),
            self.day(),
            self.month(),
            self.week(),
        ]

    def second(self) -> str:
        return self.common(0, 59)

    def minute(self) -> str:
        return self.common(0, 59)

    def hour(self) -> str:
        return self.common(0, 23)

    def day(self) -> str:
        return self.common(1, 30)

    def month(self) -> str:
        return self.common(1, 11)

    def week(self) -> str:
        return self.common(0, 6)

    def common(self, range_start, range_end) -> str:
        kind = random.choice(["", "*", "/", ",", "-"])
        if kind == "":
            return str(random.randint(range_start, range_end))
        if kind == "*":
            sub_kind = random.choice(["", "/"])
            if sub_kind == "*":
                return "*"
            return "*/" + str(random.randint(1, range_end))
        if kind == "/":
            sub_kind = random.choice(["", "-", ","])
            base = random.randint(range_start, range_end)
            per = random.randint(1, range_end)
            if sub_kind == "":
                return f"{base}/{per}"
            if sub_kind == "-":
                base2 = random.randint(base + 1, range_end)
                return f"{base}-{base2}/{per}"
            if sub_kind == ",":
                base2 = random.randint(base + 1, range_end)
                return f"{base}/{per},{base2}"
        if kind == ",":
            t1 = random.randint(range_start, range_end)
            t2 = random.randint(t1 + 1, range_end)
            t3 = random.randint(t2 + 1, range_end)
            return f"{t1},{t2},{t3}"
        if kind == "-":
            t1 = random.randint(range_start, range_end)
            t2 = random.randint(t1 + 1, range_end)
            return f"{t1}-{t2}"

        return "*"

    def to_str(self) -> str:
        return " ".join(self.cron)


def gen_fixture(count=1000) -> List[Tuple[str, datetime]]:
    fixtures = []
    i = 0
    while i < count:
        try:
            expr = RandomCron().to_str()
            if len(expr) > 32:
                continue
            c = CronTab(expr)
            expect = c.next(now=now, default_utc=True, return_datetime=True)
        except Exception:
            continue

        fixtures.append((expr, expect))
        i += 1

    return fixtures


if __name__ == "__main__":
    fixtures = gen_fixture()

    with open("./testdata/now", "w") as f:
        f.write(f"{now.strftime('%Y-%m-%d %H:%M:%S')}")

    with open("./testdata/cases", "w") as f:
        for fixture in fixtures:
            f.write(f"{fixture[0]}|{fixture[1].strftime('%Y-%m-%d %H:%M:%S')}")
            f.write("\n")
