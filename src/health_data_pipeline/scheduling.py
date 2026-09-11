"""Regras puras para selecionar competências em execuções agendadas."""

from __future__ import annotations


def decompor_competencia(competencia: int | str) -> tuple[int, int]:
    """Valida uma competência no formato YYYYMM e retorna ano e mês."""
    texto = str(competencia).strip()
    if len(texto) != 6 or not texto.isdigit():
        raise ValueError("Competência deve usar o formato YYYYMM.")
    ano = int(texto[:4])
    mes = int(texto[4:])
    if ano < 2008 or not 1 <= mes <= 12:
        raise ValueError("Competência fora do intervalo aceito pelo SIH/SUS.")
    return ano, mes


def competencia_seguinte(competencia: int | str) -> tuple[int, int]:
    """Retorna o mês imediatamente posterior, incluindo a virada do ano."""
    ano, mes = decompor_competencia(competencia)
    if mes == 12:
        return ano + 1, 1
    return ano, mes + 1


def numero_competencia(ano: int, mes: int) -> int:
    """Converte ano e mês validados para YYYYMM numérico."""
    ano_validado, mes_validado = decompor_competencia(f"{ano:04d}{mes:02d}")
    return ano_validado * 100 + mes_validado


def proxima_competencia_permitida(
    ultima_competencia: int | str,
    limite_competencia: int | str,
) -> tuple[int, int] | None:
    """Retorna o próximo mês ou ``None`` quando ele excede a trava temporal."""
    ano, mes = competencia_seguinte(ultima_competencia)
    limite_ano, limite_mes = decompor_competencia(limite_competencia)
    if numero_competencia(ano, mes) > numero_competencia(limite_ano, limite_mes):
        return None
    return ano, mes
