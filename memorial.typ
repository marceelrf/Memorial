// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}



#let article(
  title: none,
  subtitle: none,
  authors: none,
  date: none,
  abstract: none,
  abstract-title: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: "libertinus serif",
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: "libertinus serif",
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  sectionnumbering: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  set par(justify: true)
  set text(lang: lang,
           region: region,
           font: font,
           size: fontsize)
  set heading(numbering: sectionnumbering)
  if title != none {
    align(center)[#block(inset: 2em)[
      #set par(leading: heading-line-height)
      #if (heading-family != none or heading-weight != "bold" or heading-style != "normal"
           or heading-color != black) {
        set text(font: heading-family, weight: heading-weight, style: heading-style, fill: heading-color)
        text(size: title-size)[#title]
        if subtitle != none {
          parbreak()
          text(size: subtitle-size)[#subtitle]
        }
      } else {
        text(weight: "bold", size: title-size)[#title]
        if subtitle != none {
          parbreak()
          text(weight: "bold", size: subtitle-size)[#subtitle]
        }
      }
    ]]
  }

  if authors != none {
    let count = authors.len()
    let ncols = calc.min(count, 3)
    grid(
      columns: (1fr,) * ncols,
      row-gutter: 1.5em,
      ..authors.map(author =>
          align(center)[
            #author.name \
            #author.affiliation \
            #author.email
          ]
      )
    )
  }

  if date != none {
    align(center)[#block(inset: 1em)[
      #date
    ]]
  }

  if abstract != none {
    block(inset: 2em)[
    #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
    ]
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  if cols == 1 {
    doc
  } else {
    columns(cols, doc)
  }
}

#set table(
  inset: 6pt,
  stroke: none
)
/* Color links */
#show link: set text(fill: rgb(0, 0, 255))
#set par(leading: 1.0em, justify: true)
#show heading: set block(above: 1.5em, below: 1em)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
)

#show: doc => article(
  title: [Memorial circunstanciado],
  authors: (
    ( name: [Dr.~Marcel Rodrigues Ferreira],
      affiliation: [UNESP],
      email: [marcel.ferreira\@unesp.br] ),
    ),
  date: [2026-08-24],
  lang: "pt",
  region: "BR",
  sectionnumbering: "1.1.a",
  toc: true,
  toc_title: [Índice],
  toc_depth: 3,
  cols: 1,
  doc,
)

#pagebreak()
= Apresentação
<sec-1>
Ao longo da minha trajetória acadêmica, alguns acontecimentos foram particularmente marcantes e contribuíram de forma decisiva para a construção da minha identidade como pesquisador e educador. Entre eles, destaco a conclusão do ensino médio, o ingresso no curso de #link("https://www.ibb.unesp.br/#!/ensino/graduacao/curso/fisica-medica/")[Física Médica] na Universidade Estadual Paulista "Júlio de Mesquita Filho" (#link("https://www2.unesp.br/")[UNESP];), o desenvolvimento das atividades de iniciação científica, a defesa da dissertação de mestrado e da tese de doutorado, bem como o início das atividades de pós-doutorado. Esses momentos, mais do que marcos formais, representaram etapas fundamentais de reflexão, amadurecimento e definição de objetivos acadêmicos e profissionais.

Embora tais conquistas sejam, frequentemente, associadas a celebrações, sempre as compreendi como oportunidades de análise crítica da própria trajetória, permitindo ajustes de rota e o delineamento de novos objetivos. Mesmo diante dos desafios e das incertezas inerentes à carreira acadêmica, mantive de forma consistente o propósito de me tornar professor universitário em regime de dedicação integral ao ensino, à pesquisa e à formação de recursos humanos, entendendo a universidade pública como espaço privilegiado de produção de conhecimento, inclusão e transformação social.

Minha formação científica foi construída em ambientes interdisciplinares, com forte integração entre ciências básicas, biologia molecular, bioinformática e ciência dos biomateriais, possibilitando uma atuação científica que transita entre abordagens experimentais e computacionais. Ao longo desse percurso, busquei consolidar uma base sólida em pesquisa, ampliar redes de colaboração nacionais e internacionais e desenvolver competências didáticas voltadas à formação crítica de estudantes de graduação e pós-graduação.

O presente memorial tem como objetivo apresentar uma análise circunstanciada da minha trajetória acadêmica e profissional, no contexto de minha candidatura à carreira docente. Este documento reúne informações que não se encontram integralmente descritas em currículos ou bases públicas, oferecendo uma visão integrada das atividades desenvolvidas, das contribuições científicas realizadas e das perspectivas futuras de atuação acadêmica.

As informações pessoais relevantes estão resumidas na Seção #link(<sec-2>)[2];. As Seções #link(<sec-3>)[3] e #link(<sec-4>)[4] apresentam, respectivamente, minha formação acadêmica e científica e minha atuação profissional. As seções subsequentes estão organizadas da seguinte forma: (i) Atividades Didáticas e Formação de Recursos Humanos (Seção #link(<sec-5>)[5];); (ii) Atividades de Pesquisa (Seção #link(<sec-6>)[6];); (iii) Atividades de Extensão e Serviços à Comunidade (Seção #link(<sec-7>)[7];); e (iv) Atividades Administrativas (Seção #link(<sec-8>)[8];). Na Seção #link(<sec-9>)[9] é apresentada a nomenclatura adotada para os anexos. Por fim, na Seção #link(<sec-10>)[10];, apresento considerações finais, sintetizando minha trajetória e as perspectivas de desenvolvimento acadêmico.

== Missão
<missão>
#quote(block: true)[
#emph[Ser um laboratório que proporciona um ambiente estimulante, visando maximizar o potencial dos alunos tanto como cientistas quanto como indivíduos.];#footnote[#emph[Esta frase foi retirada de um artigo do professor Uri Alon (Alon 2009). Poucas vezes em minha vida puder ler meus valores em uma frase de outra pessoa como esta vez.];]
]

== Visão
<visão>
De modo a guiar a criação e consolidação do laboratório proposto, apresento a visão para ele:

- Excelência em Pesquisa Científica;

- Integração com a Comunidade Acadêmica e Local;

- Fomentar a Colaboração Internacional;

- Formação de Novos Líderes em Pesquisa;

- Inovação Contínua e Adaptação;

- Liderança em Ética e Integridade Científica;

- Impacto Duradouro na Formação Acadêmica;

- Orgulho Institucional e Reconhecimento;

== Agradecimento especial
<agradecimento-especial>
Gostaria de expressar minha sincera gratidão ao Prof.~Dr.~Juarez Lopes Ferreira da Silva, ilustre membro do Departamento de Físico-Química do Instituto de Química de São Carlos da Universidade de São Paulo, por sua generosidade em compartilhar publicamente seu memorial no ResearchGate. Embora ainda não tenhamos tido a oportunidade de nos conhecer pessoalmente, a iniciativa do professor de disponibilizar seu trabalho tem sido de imensa valia para minha trajetória acadêmica e profissional.

#pagebreak()
= Dados pessoais
<sec-2>
#strong[Nome Completo:] Marcel Rodrigues Ferreira.

#strong[Nome Científico:] Marcel R. Ferreira

#strong[Nome em Citações:] M.R.Ferreira.

#strong[Data de Nascimento:] 02/05/1991.

#strong[Estado Civil:] Solteiro.

#strong[Local de Nascimento:] Itapetininga, São Paulo, Brasil.

#strong[Nacionalidade:] Brasileira.

#strong[Endereço Profissional:] Universidade Estadual Paulista "Júlio de Mesquita Filho", Faculdade de Medicina de Botucatu, Unidade de Pesquisa Experimental (UNIPEX). Av. Prof.~Mário Rubens Guimarães Montenegro,~s/n Bairro: Distrito de Rubião Júnior. Cep: 18.618-687 - Botucatu, SP

#strong[Telefone Profissional:] (14) 3880-1749.

#strong[E-mail:] #link("mailto:marcel.ferreira@unesp.br")[marcel.ferreira\@unesp.br];.

#strong[CV Lattes:] #link("http://lattes.cnpq.br/5630742099737794");.

#strong[ORCID:] #link("https://orcid.org/0000-0002-3445-0945");.

#strong[Web of Science ResearcherID:] A-5830-2018

#strong[Google Scholar:] #link("https://scholar.google.com.br/citations?user=lS42GYwAAAAJ&hl=pt-BR")

#strong[Scopus];#footnote[Na plataforma Scopus meu nome esta como Marcel Rodrigues Rodrigues Ferreira. Já foi solicitado mais de uma vez a correção, porém até a presente data não foi realizada.];#strong[:] #link("https://www.scopus.com/authid/detail.uri?authorId=56765071000")

#strong[Website:] #link("http://marceelrf.netlify.app/")

#strong[ResearchGate:] #link("https://www.researchgate.net/profile/Marcel-Rodrigues-Ferreira?ev=hdr_xprf.")

#strong[Linkedin:] #link("https://www.linkedin.com/in/marceelrf/")

#strong[GitHub:] #link("https://github.com/marceelrf")

#pagebreak()
= Formação Acadêmica e Científica
<sec-3>
== Ensino Fundamental e Médio: 1998-2008
<ensino-fundamental-e-médio-1998-2008>
Minha trajetória educacional começou na cidade de Itapetininga, interior de São Paulo, onde tive a sorte de ser cercado por um ambiente familiar que valorizava a educação e o desenvolvimento integral desde cedo. Meus pais, pertencentes à classe média baixa, fizeram um esforço considerável para me matricular em instituições de ensino que pudessem proporcionar uma formação de qualidade, entendendo que a educação seria a base para minhas futuras conquistas.

O ensino fundamental foi realizado no Colégio Alpis, entre os anos de 1998 e 2005. Durante esse período, além do currículo escolar tradicional, meus pais incentivaram práticas esportivas, estudos de língua inglesa e artes, com aulas de violão, o que contribuiu significativamente para uma visão mais ampla e multidisciplinar do mundo.

Entre 2006 e 2008, cursei o ensino médio no Sistema Educacional Quintal (Objetivo). Essa etapa foi particularmente inspiradora, graças às aulas de laboratório de química, física e biologia que frequentava no período vespertino. Essas experiências práticas foram fundamentais para despertar meu interesse por uma carreira científica, mostrando-me a importância da experimentação e do conhecimento aplicado.

Ambas as escolas desempenharam um papel crucial na minha formação, reforçando a ideia de que uma educação abrangente e multidisciplinar é essencial para o desenvolvimento pessoal e profissional. Sou extremamente grato aos meus pais pelo sacrifício em custear escolas particulares, que, apesar dos desafios financeiros, sempre priorizaram meu aprendizado e crescimento.

== Graduação: 2011--2014
<graduação-20112014>
Após dois anos pessoalmente muito dificies, em 2011 entrei no curso de Bacharelado em Física Médica do Insituto de Biociências de Botucatu da Universidade Estadual Paulista "Júlio de Mesquita Filho" (#link("https://www2.unesp.br/")[UNESP];). Durante os 4 anos de curso, tive acesso a uma formação multidisciplinar. Ainda nas primeiras semanas, ouvi a frase "aproveitem todos os espaços que a universidade pública lhes proporciona" e tomei-a como meu mantra. Participei de diversas atividades acadêmicas como: o cursinhos pré-vestibular Desafio e Eukaípia, empresa júnior Nucleon Jr, atlética, organização do Congresso de Física Aplicada a Medicina, monitorias, e iniciação cientifica.

Após enfrentar dois anos de desafios pessoais significativos, ingressei, em 2011, no curso de Bacharelado em Física Médica do Instituto de Biociências de Botucatu da Universidade Estadual Paulista "Júlio de Mesquita Filho" (#link("https://www2.unesp.br/")[UNESP];). Ao longo dos quatro anos de graduação, tive a oportunidade de acessar uma formação profundamente multidisciplinar, que abrangeu desde os fundamentos da física até aplicações práticas na medicina.

Nas primeiras semanas de curso, uma orientação ressoou em minha mente como um mantra: "#emph[aproveitem todos os espaços que a universidade pública lhes proporciona];". Inspirado por essa mensagem, participei ativamente de diversas atividades acadêmicas e extracurriculares, incluindo:

- #strong[Cursinhos pré-vestibular];: Contribuí como professor e monitor de matemática no #link("https://www.fmb.unesp.br/#!/extensao/cursinho-desafio/")[cursinho Desafio] (2011) e como professor e coordenador de matemática no projeto Eukaípia #footnote[O cursinho Eukaípia, do qual fui participante, foi renomeado em 2014 para Cursinho do IB e, posteriormente, em 2017, para #link("https://www.ibb.unesp.br/#!/extensao/cursinhos-athena/")[Cursinho Athena] --- denominação que tive a honra de sugerir. Durante as etapas de meu mestrado e doutorado, não apenas continuei como professor, mas também assumi a função de coordenador de disciplina nesses projetos, contribuindo para a sua evolução e impacto na comunidade.] (2012-2013), ambos voltados para a preparação de estudantes de baixa renda para o vestibular.

- #strong[Empresa júnior];: Fui membro da Nucleon Jr, onde adquiri experiência prática em consultoria e projetos relacionados à física médica.

- #strong[Atlética];: Fui membro ativo da Associação Atlética Acadêmica de Botucatu, como atleta e, posteriormente, como Diretor de Modalidade de Tênis de Mesa. Nessa função, tive a oportunidade de influenciar significativamente a prática do esporte, conduzindo a equipe a resultados expressivos em competições e incentivando um aumento no número de praticantes da modalidade.

- #strong[Organização de eventos];: Auxiliei na organização do Congresso de Física Aplicada à Medicina de 2014, uma experiência enriquecedora que me permitiu interagir com profissionais e pesquisadores renomados na área.

- #strong[Monitorias];: Atuei como monitor nas disciplinas de Física 3 para os cursos de Física Médica e de Fundamentos de Física do curso de Ciências Biomédicas, reforçando meu conhecimento e auxiliando colegas em suas jornadas acadêmicas.

- #strong[Iniciação científica];: Engajei-me em projetos de pesquisa, fundamentais para o desenvolvimento de meu pensamento crítico e habilidades científicas.

- #strong[Recepção universitária];: Nos anos de 2012 e 2013 participei da organização da recepção do calouros do Instituto de Biociências de Botucatu.

Tive a oportunidade de cursar diversas disciplinas durante os 4 anos de curso de Física Médica, abrangendo várias áreas do conhecimento, incluindo Humanas, Biológicas e, claro, Exatas. Essa diversidade de temas enriqueceu minha formação e proporcionou uma visão mais holística e integrada das ciências. Essa abordagem multidisciplinar foi essencial para minha formação, com destaque para as disciplinas de Linguagem de Programação, Bioquímica Básica, Biofísica Molecular e Física Computacional, que foram fundamentais para minha trajetória acadêmica e profissional. No terceiro ano, iniciei minha jornada científica sob a orientação do #link("http://lattes.cnpq.br/8213371495151651")[Prof.~Dr.~Mario de Oliveira Neto];, do Departamento de Física e Biofísica (atualmente Biofísica e Farmacologia), com uma bolsa PIBIC/PROPe#footnote[PIBIC: Programa Institucional de Bolsas de Iniciação Científica. PROPe: Pró-Reitoria de Pesquisa.] via CNPq. Nesse período, mergulhei no estudo da estrutura de proteínas, utilizando dados de espalhamento de raios X a baixo ângulo (SAXS) e tive meu primeiro contato com bases de dados biológicas. Embora o projeto original, focado em proteínas relacionadas ao câncer bucal, não tenha avançado, desenvolvi outro sobre proteínas envolvidas na produção de etanol de segunda geração, que, embora não alinhasse diretamente com meu desejo de atuar no setor da saúde, proporcionou valiosos aprendizados. Durante quase dois anos, refinei minhas habilidades na extração de informações de bases de dados públicas, culminando na apresentação do trabalho no congresso de iniciação científica da UNESP, no qual fui classificado para a fase final do evento. Esse período resultou na participação em dois artigos científicos, publicados em 2015 (Alvarez et al. 2015) e em 2022 (Franco Cairo et al. 2022). As principais informações estão resumidas a seguir:

#line(length: 50%, stroke: white)
#strong[Curso:] Bacharelado em Física Médica.

#strong[Instituição:] Instituto de Biociências de Botucatu, da Universidade Estadual Paulista "Júlio de Mesquita Filho".

#strong[Local:] Campus Rubião Junior, Botucatu, São Paulo, Brasil.

#strong[Monografia:] Espalhamento de raios-X a baixo ângulo aplicado a caracterização de enzimas celulolíticas com potencial na transformação enzimática da biomassa.

#strong[Orientador];: Prof.~Dr.~José Mario de Oliveira Neto.

#strong[Iniciação Científica];: 12 meses com bolsa fornecida pelo CNPq,Universidade Estadual Paulista "Júlio de Mesquita Filho".

== Mestrado: 2015--2017
<mestrado-20152017>
No último ano de graduação tive a oportunidade de assistir uma palestra do #link("http://lattes.cnpq.br/9087428606376572")[Prof.~Dr.~Willian Fernando Zambuzzi] sobre a utilização de mecanismos de transdução de sinais intracelulares com fator para a predição para o desenvolvimento de biomateriais. Fiquei impactado com essa perspectiva e quando ao final de sua apresentação ele declarou que procurava alunos de pósgraduação para orientar no #link("https://www.ibb.unesp.br/#!/ensino/pos-graduacao/programas-stricto-sensu/biotecnologia/")[PPG de Biotecnologia] que teria suas primeiras turmas de mestrado e doutorado não hesitei em enviar um e-mail sobre a possibilidade de fazer mestrado sob sua orientação. Fiz parte da primeira geração de pós-graduandos no recém fundado Laboratório de Bioensaios e Dinâmica celular no departamento de Química e Bioquímica, e pude acompanhar, e trabalhar para a consolidação dela como um grupo de excelência em pesquisa. Meu projeto de mestrado visava utilizar mecanismos de transdução de sinais de células cultivadas diretamente sobre superfícies de biomateriais. Para isso, utilizamos o método de avaliação do quinoma por meio de microarranjo de peptídeos (PamChip®). Tive o privilégio de ter meu projeto financiado pela FAPESP (2015/03639-8) e vivi um período de muito aprendizado durante sua execução.

Durante a execução do projeto de mestrado, adquiri uma formação sólida em técnicas de cultivo celular, incluindo manutenção, expansão e experimentação com diferentes linhagens celulares, bem como a padronização de ensaios #emph[in vitro] aplicados à avaliação da interação célula--biomaterial. Nesse contexto, tive contato e treinamento em técnicas laboratoriais amplamente utilizadas em pesquisa biomédica, como Western blotting para análise de proteínas e vias de sinalização, microscopia eletrônica de varredura (MEV) associada à espectroscopia de energia dispersiva de raios X (EDX) para caracterização de superfícies de biomateriais e de células em adesão, além de ensaios de citotoxicidade baseados em MTT, cristal violeta e vermelho neutro. Esse período foi fundamental para o desenvolvimento de uma compreensão aprofundada dos mecanismos de sinalização celular, com ênfase em vias reguladas por quinases e fosfatases, possibilitando a interpretação crítica das respostas celulares diante de diferentes superfícies e estímulos físico-químicos.

Paralelamente, o projeto demandou o tratamento e a análise de grandes volumes de dados oriundos de experimentos de alto rendimento, o que motivou meu primeiro contato sistemático com a programação em linguagem R. Nesse contexto, desenvolvi habilidades em bioestatística e análise de dados, aplicando métodos estatísticos apropriados à interpretação dos resultados experimentais e à visualização gráfica das informações obtidas. Esses aprendizados foram decisivos para a consolidação de uma abordagem quantitativa e integrada da pesquisa científica, influenciando de maneira permanente minha formação como pesquisador e servindo de base para as atividades desenvolvidas em etapas posteriores da carreira acadêmica.

Foi também durante o mestrado que despertei um interesse consistente pelo desenvolvimento e pela aplicação de métodos alternativos ao uso de animais em pesquisa, especialmente no contexto da avaliação de biomateriais médico-odontológicos. A utilização de modelos celulares e abordagens baseadas em mecanismos de sinalização intracelular mostrou-se uma estratégia robusta, ética e cientificamente informativa, direcionando de forma permanente minhas linhas de investigação posteriores.

Como resultado desse período de formação, o trabalho desenvolvido deu origem a um artigo científico diretamente relacionado à dissertação de mestrado (Marcel Rodrigues Ferreira et al. 2020), além de duas publicações adicionais, de caráter paralelo, construídas a partir de colaborações estabelecidas durante o projeto, com divisão de autoria entre os pesquisadores envolvidos Fernandes et al. (2018).

#line(length: 50%, stroke: white)
#strong[Instituição:] Universidade Estadual Paulista, Insituto de Biociências de Botucatu.

#strong[Local:] Botucatu, São Paulo, Brasil.

#strong[Título];: Mestre em Biotecnologia.

#strong[Área:] Biotecnologia.

#strong[Dissertação:] OsteoBLAST: Rotina computacional de análise molecular global aliada à biologia sistêmica e aplicada à produção de biomateriais.

#strong[Orientador:] #link("http://lattes.cnpq.br/9087428606376572")[Prof.~Dr.~Willian Fernando Zambuzzi]

#strong[Data de defesa:] 24/02/2017

#strong[Bolsa:] FAPESP (2015/03639-8)

== Doutorado: 2017-2023
<doutorado-2017-2023>
Ao final do mestrado, eu percebia que, por mais que as premissas de nosso trabalho fossem importantes, havia claras limitações nas metodologias propostas. A primeira foi o uso de uma tecnologia fechada, como a PamChip®, exclusiva da empresa PamGene. Este fato, somado a empresa não ter atuação no Brasil, diminuía o potencial de escalabilidade da tecnologia por nós proposta.

Embora a avaliação da atividade de quinases possua um elevado valor no entendimento do fluxo de informação biológica, hoje tenho o entendimento que o uso de métodos baseados em transcriptoma, são uma solução melhor para nossa proposta uma vez que são métodos amplamente difundidos na comunidade científica. A segunda limitação se dava na falta de conhecimento em métodos de análise físico-química das superfícies dos biomateriais. Esta segunda limitação me fez propor um projeto de doutorado que envolvesse mais métodos de síntese e caracterização de biomateriais, no caso fosfatos de cálcio. Meu orientador concordou e sugeriu que buscássemos trabalhar com a modificação destas superfícies com fatores de crescimento através do uso de plasma-rico em plaquetas (PRP).

Ao longo do doutorado, aprofundei e ampliei significativamente minha formação metodológica e conceitual, incorporando abordagens experimentais e analíticas que supriram limitações identificadas ao final do mestrado. Um dos avanços centrais desse período foi a incorporação de métodos baseados em transcriptômica, incluindo análise de miRNAs, aprendizado adquirido em um curso de verão realizado na Universidade de São Paulo, campus de Ribeirão Preto. Paralelamente, desenvolvi competências no processamento de plasma rico em plaquetas (PRP) e na síntese de diferentes fosfatos de cálcio, como hidroxiapatita, monetita e fosfato tricálcico (TCP), bem como na caracterização desses biomateriais por técnicas físico-químicas consolidadas, incluindo FTIR, difração de raios X (DRX), análise termogravimétrica (TGA) e ICP-MS. Também aprofundei o uso de métodos de análise de expressão gênica relativa, fortalecendo a integração entre dados moleculares e propriedades dos biomateriais. Ao longo desse período, busquei continuamente a qualificação em análise de dados, tendo realizado mais de vinte cursos de curta duração em programação e análise estatística utilizando as linguagens R e Python, o que contribuiu de forma decisiva para minha autonomia analítica e capacidade de lidar com dados complexos.

A trajetória do doutorado, no entanto, não se deu sem desafios. Ao optar por permanecer em um programa de pós-graduação em estágio de consolidação, enfrentei inicialmente a ausência de bolsas de fomento, o que me levou a atuar como professor particular de matemática e física em Botucatu durante todo o ano de 2017 e início de 2018. Essa condição impactou o ritmo inicial do projeto, situação que começou a ser revertida com a aprovação da minha bolsa FAPESP em julho de 2018. Após um período de reorganização e normalização do cronograma experimental, um novo e inesperado desafio se impôs com a pandemia de COVID-19. O fechamento repentino do laboratório, aliado às restrições sanitárias, resultou em perdas experimentais significativas, incluindo experimentos de longa duração e grupos experimentais comprometidos por falhas em equipamentos, não prontamente detectadas devido à ausência de pessoal no laboratório. Apesar dos impactos científicos e emocionais desse período, considero que essa adversidade contribuiu para meu amadurecimento acadêmico, exigindo adaptações no projeto e na estrutura da tese, além de resiliência e capacidade de replanejamento.

Entre as principais conquistas do doutorado, destaco a aprovação da bolsa FAPESP, cuja avaliação foi fortemente impactada pela perspectiva de realização de um estágio de pesquisa no exterior (BEPE), previamente alinhado com o Prof.~Dr.~Paulo G. Coelho, da New York University (NYU). No contexto dessa colaboração, o Prof.~Dr.~Lukasz Witek, então colaborador do Prof.~Paulo, esteve em Botucatu em 2018 para ministrar treinamento e disciplina, fortalecendo a interação entre os grupos. Posteriormente, considerando sua transição institucional, o Prof.~Paulo sugeriu que o Prof.~Dr.~Lukasz Witek assumisse a supervisão do estágio BEPE. Assim, entre 01/04/2022 e 31/12/2022, realizei estágio no Departamento de Patobiologia Molecular da Faculdade de Odontologia da NYU, sob supervisão do Prof.~Dr.~Lukasz Witek. Nesse período, tive contato com métodos avançados de análise in vitro de biomateriais ósseos, desenvolvimento de tintas para impressão 3D voltadas à regeneração óssea, técnicas de reologia, além de atuar na coordenação dos experimentos de cultura celular do laboratório. Essa experiência resultou em uma publicação científica direta com o grupo anfitrião e proporcionou uma vivência intensa em um ambiente internacional de excelência em pesquisa.

Ao longo do doutorado, publiquei diversos trabalhos científicos, tanto como primeiro autor quanto como colaborador. Dentre eles, destaco o artigo "#emph[Platelet microparticles load a repertory of miRNAs programmed to drive osteogenic phenotype];" (Marcel Rodrigues Ferreira e Zambuzzi 2021), que compôs um dos capítulos da minha tese; o trabalho "#emph[GSVA score reveals molecular signatures from transcriptomes for biomaterials comparison];" (Marcel R. Ferreira et al. 2020), inicialmente concebido como um projeto paralelo e que se tornou o artigo com maior número de citações da minha produção; e o artigo "#emph[Mesenchymal Stem Cell Differentiation Induced by Lyophilized PRP During Early Osteogenesis];" (Marcel Rodrigues Ferreira et al. 2025), publicado em 2026, que representa o principal produto científico do doutorado.

Adicionalmente, esse período marcou o início da minha consolidação como pesquisador independente, com o estabelecimento de novas colaborações, incluindo parcerias com o Prof.~Dr.~Rodrigo Cardoso de Oliveira (USP Bauru) e com os Profs. Rodrigo Augusto Foganholi da Silva e Denise Carletto Andia (Universidade Paulista). Tive também a oportunidade de coorientar alunos de iniciação científica em conjunto com o Prof.~Dr.~Willian Fernando Zambuzzi, participando ativamente da formação de Guilherme Gazolla Santana (FAPESP 2019/09943-1), Júlia Ferreira de Moraes (FAPESP 2022/14363-7) e Matheus Amaral Silva, experiência fundamental para o desenvolvimento da minha identidade como orientador e mentor acadêmico.

#line(length: 50%, stroke: white)
#strong[Instituição:] Universidade Estadual Paulista, Insituto de Biociências de Botucatu.

#strong[Local:] Botucatu, São Paulo, Brasil.

#strong[Título];: Doutor em Biotecnologia.

#strong[Área:] Biotecnologia.

#strong[Dissertação:] Plasma-rico em plaquetas liofilizado associado à nanohidroxiapatita na performance celular e regeneração óssea.

#strong[Orientador:] #link("http://lattes.cnpq.br/9087428606376572")[Prof.~Dr.~Willian Fernando Zambuzzi]

#strong[Data de defesa:] 20/01/2023

#strong[Bolsa:] FAPESP (2018/05731-7)

#strong[Internacionalização:] Universidade de Nova Iorque (NYU), supervisão do Prof.~Dr.~Lukasz Witek. BEPE: "Plasma rico em plaquetas e fabricação de aditivos como uma alternativa promissora para ajudar a desenvolver ossos verdadeiro". Bolsa: FAPESP(2021/14271-2).

#pagebreak()
= Atuação Profissional
<sec-4>
== Pós-doutorados: 2023-Presente
<pós-doutorados-2023-presente>
Ao final do doutorado, passei a refletir de forma mais estruturada sobre os próximos passos da minha trajetória científica, identificando a necessidade de aprofundar minha formação em programação e métodos computacionais avançados como um eixo central de atuação profissional. Tornou-se claro que o domínio de estratégias de análise de dados em larga escala e a implementação de modelos de machine learning seriam componentes fundamentais para consolidar uma carreira voltada ao desenvolvimento de métodos analíticos em bioinformática e ciências ômicas.

Nesse contexto, iniciei um estágio de pós-doutorado sob a supervisão do Dr.~Erick da Cruz Castelli, pesquisador que acompanho há anos e cuja atuação na área de bioinformática se destaca pela sólida integração entre rigor biológico e excelência no desenvolvimento de ferramentas computacionais. Desde maio de 2023, venho atuando em seu grupo de pesquisa em diferentes projetos, o que tem ampliado de forma consistente minha formação em genômica, epigenômica e transcriptômica, além de proporcionar um aprofundamento significativo em ambientes computacionais e práticas de programação, incluindo Linux, uso de containers Docker, gerenciamento de ambientes Conda, computação em nuvem e aplicações de machine learning.

Esse período de pós-doutorado tem sido fundamental para a consolidação de uma visão de carreira orientada à liderança científica, ao desenvolvimento de métodos analíticos robustos e à coordenação de projetos interdisciplinares, integrando biologia, ciência de dados e bioinformática. A trajetória construída até o momento reforça minha capacitação para assumir a coordenação de projetos de pesquisa de maior complexidade, com autonomia técnica e visão estratégica.

=== 1º Período -- Bolsa CAPES/PROCAD (#strong[Maio de 2023 -- Janeiro de 2025)]
<º-período-bolsa-capesprocad-maio-de-2023-janeiro-de-2025>
O primeiro período do pós-doutorado foi realizado com bolsa CAPES, no âmbito do Projeto PROCAD -- Edital nº 16/2020 (Processos 88887.516236/2020-00 e 88881.516238/2020-01), intitulado "Epigenética e fenotipagem forense por DNA: uso e implementação da plataforma Oxford Nanopore para sequenciamento de nova geração". As atividades foram desenvolvidas sob a supervisão do Dr.~Erick da Cruz Castelli, integrando o projeto liderado pelo Prof.~Dr.~Celso Teixeira Mendes Junior, em colaboração com a Profa. Dra. Silviene Fabiana de Oliveira.

Nesse período, atuei no desenvolvimento de estratégias computacionais e na padronização de protocolos de extração de DNA de alto peso molecular, voltados à aplicação de tecnologias de sequenciamento por long reads utilizando a plataforma Oxford Nanopore. As atividades envolveram desde etapas experimentais até a análise bioinformática, com ênfase na interpretação de dados epigenéticos e genômicos aplicados à genética forense.

Como resultado dessa atuação, participei da elaboração do artigo de revisão "#emph[Advances in forensic genetics: Exploring the potential of long read sequencing];", publicado na revista Forensic Science International: Genetics, consolidando uma visão crítica sobre o uso de tecnologias de sequenciamento de terceira geração no contexto forense.

Adicionalmente, atuei como organizador e docente dos cursos de difusão "#link("https://workshopbioinfoforense.netlify.app/")[#emph[Workshop de Bioinformática Aplicada à Genética Forense: Análise de Dados de Sequenciamento de Segunda e Terceira Geração];];", ministrados em duas edições (2023 e 2024), contribuindo diretamente para a formação de estudantes e profissionais na área.

Este primeiro período foi marcado por um intenso processo de aprendizado e amadurecimento científico, com aprofundamento na análise de modificações de bases, especialmente metilação em dinucleotídeos CpG, análise de variantes, desenvolvimento de softwares biológicos e consolidação de competências em bioinformática aplicada. Esse conjunto de experiências foi fundamental para o fortalecimento da minha autonomia como pesquisador e para a construção de uma base sólida para etapas posteriores do pós-doutorado e da carreira científica.

=== 2º Período -- Bolsa CAPES/PIPD (#strong[Fevereiro de 2025 -- Atualmente)]
<º-período-bolsa-capespipd-fevereiro-de-2025-atualmente>
Com a aproximação do término do período original do pós-doutorado (inicialmente previsto para abril de 2025), avaliei a possibilidade de realizar um estágio pós-doutoral no exterior. No entanto, a abertura de um edital de pós-doutorado vinculado ao Programa de Pós-Graduação em Ciências Biológicas -- Genética, do Instituto de Biociências de Botucatu, apresentou-se como uma oportunidade estratégica para a consolidação da minha trajetória acadêmica no país.

Além de permitir a continuidade e o aprofundamento de linhas de pesquisa já em andamento, esse segundo período possibilitou o credenciamento junto a um programa de pós-graduação com conceito CAPES 6, aspecto especialmente relevante para o fortalecimento do meu currículo acadêmico, considerando experiências anteriores em processos seletivos para a carreira docente. A inserção formal no programa representou um passo fundamental para o desenvolvimento de atividades regulares de ensino e orientação em nível de pós-graduação.

Desde maio de 2025, atuo como professor colaborador do Programa de Pós-Graduação em Ciências Biológicas -- Genética, tendo criado e ministrado duas disciplinas, ampliando minha experiência didática e minha integração às atividades acadêmicas do programa.

No âmbito da formação de recursos humanos, passei a atuar de maneira direta em atividades de orientação, realizando a orientação da aluna Juliana Azevedo Amaral e a coorientação da aluna de iniciação científica Isabela Lorente Kraetzer, ambas desenvolvidas junto ao Prof.~Dr.~Erick da Cruz Castelli, meu supervisor. Adicionalmente, atuo na coorientação da aluna Beatriz Camargo, doutoranda do Programa de Pós-Graduação em Biotecnologia, em colaboração com o Prof.~Dr.~Willian Fernando Zambuzzi, ampliando minha atuação em diferentes níveis da pós-graduação.

No campo da pesquisa, este período também foi marcado pela ampliação das atividades experimentais e computacionais, incluindo a realização de sequenciamentos de genoma completo utilizando a plataforma Oxford Nanopore, diretamente relacionados aos projetos em desenvolvimento no grupo. Essas atividades fortaleceram ainda mais a integração entre geração de dados, análise bioinformática e aplicação de tecnologias de sequenciamento de terceira geração.

Este segundo período configura-se, portanto, como uma extensão natural e estratégica do pós-doutorado, voltada não apenas à produção científica, mas também à consolidação do perfil docente, à atuação em programas de excelência e à preparação para a coordenação de projetos de pesquisa e formação de recursos humanos.

#pagebreak()
= Atividades Didáticas e Formação de Recursos Humanos
<sec-5>
== Atividades de Monitoria
<atividades-de-monitoria>
+ Monitor na disciplina de Física III do Curso de Física Médica (Ano #strong[2013];; Carga horária: 2). Responsável: #link("http://lattes.cnpq.br/8949540199759267")[Prof.~Dr.~Joel Mesa Hormaza];;
+ Monitor na disciplina de Fundamentos da Física do Curso de Ciências Biomédicas (Ano #strong[2013];; Carga horária: 1). Responsável: #link("http://lattes.cnpq.br/3740074012748153")[Proj. Dr.~Jose Luiz Rybarczyk Filho];;

== Disciplinas Ministradas
<disciplinas-ministradas>
=== Disciplinas de pós-graduação
<disciplinas-de-pós-graduação>
+ #strong[GEN001631] - Sequenciamento de Terceira Geração com Oxford Nanopore: Princípios e Aplicações em Bioinformática (Carga horária #underline[#strong[30 horas];];).
+ #strong[GEN001641] - Desenvolvimento de pacotes e aplicativos biológicos com R (Carga horária #underline[#strong[30 horas];];).

== Orientações em Nível de Graduação
<orientações-em-nível-de-graduação>
+ #link("http://lattes.cnpq.br/0088184184301073")[#strong[Juliana Azevedo Amaral];];. "#emph[Desenvolvimento de um Aplicativo para Gestão Integrada de Dados de Bioinformática em Análises Forenses];". Início: 2025. Fim: 2026. Iniciação científica (Graduanda em Ciências Biomédicas);
+ #link("http://lattes.cnpq.br/0088184184301073")[#strong[Juliana Azevedo Amaral];];. "#emph[Caracterização haplotípica e epigenômica da região OCA2-HERC2];". Início: 2026. Fim: #strong[EM ANDAMENTO];. Iniciação científica (Graduanda em Ciências Biomédicas). FAPESP: 2025/28063-3
+ #link("http://lattes.cnpq.br/0173179889510278")[#strong[Caike Santos Souza];];. "#emph[Análise populacional da inserção AluYa5 na região promotora de TYR];". Início: 2026. Fim: #strong[EM ANDAMENTO];. Iniciação científica (Graduando em Ciências Biológicas);

== Coorientações em Nível de Graduação
<coorientações-em-nível-de-graduação>
+ #link("http://lattes.cnpq.br/7752316236611770")[#strong[Guilherme Gazolla Santana];];. Trabalho de conclusão de curso "#emph[Assinaturas moleculares do transcriptoma de células tronco mesenquimais do tecido adiposo em diferenciação: um olhar especial para a inflamação];" \[#link("https://repositorio.unesp.br/entities/publication/dc22dfd9-290c-4a29-94fa-31fca0da4d67")[link];\]. Início: 2019. Fim: 2023. Iniciação científica (Bacharel em Física Médica). FAPESP: 2019/09943-1. Orientador: #link("http://lattes.cnpq.br/9087428606376572")[Prof.~Dr.~Willian Fernando Zambuzzi];;
+ #link("http://lattes.cnpq.br/4834833217154689")[#strong[Júlia Ferreira de Moraes];];. Trabalho de conclusão de curso "#emph[Construção e caracterização de um modelo de scaffolds ósseo á base de hidrogéis];" \[#link("https://repositorio.unesp.br/entities/publication/dbd6d766-312d-4a2c-8b90-347ca5023904")[link];\]. Início: 2021. Fim: 2023. Iniciação científica (Bacharel em Física Médica). FAPESP: 2022/14363-7. Orientador: #link("http://lattes.cnpq.br/9087428606376572")[Prof.~Dr.~Willian Fernando Zambuzzi];;
+ #link("http://lattes.cnpq.br/0212300912963206")[#strong[Matheus Amaral Silva];];. Trabalho de conclusão de curso "#emph[OsteoCLUST: clusterização da resposta à biomateriais ósseos];" \[#link("https://repositorio.unesp.br/entities/publication/53dcc731-3e00-4626-acd9-0ae1d45bb8b7")[link];\]. Início: 2022. Fim: 2023. Iniciação científica (Bacharel em Física Médica). Orientador: #link("http://lattes.cnpq.br/9087428606376572")[Prof.~Dr.~Willian Fernando Zambuzzi];;
+ #strong[Isabela Lorente Kraetzer];. Iniciação científica "#emph[Desenvolvimento de um Aplicativo para Visualização da Predição de Fenótipo e Ancestralidade com Base em Genótipos];". Início: 2025. Fim: #strong[EM ANDAMENTO];. Orientador: Prof.~Dr.~Erick da Cruz Castelli;

== Orientações em Nível de Pós-graduação
<orientações-em-nível-de-pós-graduação>
Até o momento não existem orientações a serem reportadas.

== Coorientações em Nível de Pós-graduação
<coorientações-em-nível-de-pós-graduação>
+ #link("http://lattes.cnpq.br/0212300912963206")[#strong[Matheus Amaral Silva];];. "#emph[OsteoCLUST: framework para clusterização da resposta de biomateriais ósseos];" \[#link("https://repositorio.unesp.br/entities/publication/7f5dbc9f-d610-4ed2-bb56-ce3d92f40cb7")[link];\]. Início: 2023. Fim: 2025. Mestrado em Biotecnologia (IBB/UNESP). Orientador: #link("http://lattes.cnpq.br/9087428606376572")[Prof.~Dr.~Willian Fernando Zambuzzi];;
+ #link("http://lattes.cnpq.br/4834833217154689")[#strong[Júlia Ferreira de Moraes];];. "#emph[Construção de unidades biomiméticas à partir de plasma rico em plaquetas associado ao fluído caótico utilizando misturadores estáticos: perspectivas de novos processos biotecnológicos para regeneração do tecido ósseo.];". Início: 2024. Fim: #strong[EM ANDAMENTO];. Mestrado em Biotecnologia (IBB/UNESP). FAPESP: 2023/14547-3. Orientador: #link("http://lattes.cnpq.br/9087428606376572")[Prof.~Dr.~Willian Fernando Zambuzzi];;
+ #link("http://lattes.cnpq.br/9381802272385312")[#strong[Beatriz de Almeida Camargo Sormani];];. Doutorado em andamento "#emph[Impacto dos fatores tróficos liberados por células endoteliais na regulação epigenética dos membros da família do colágeno durante a mineralização de osteblastos humanos];". Início: 2024. Fim: #strong[EM ANDAMENTO];. Doutorado (IBB/UNESP). Orientador: #link("http://lattes.cnpq.br/9087428606376572")[Prof.~Dr.~Willian Fernando];;

#pagebreak()
= Atividades de Pesquisa
<sec-6>
== Linhas de Pesquisa
<linhas-de-pesquisa>
Ao longo de minha trajetória acadêmica, concentrei-me em explorar e aprofundar o conhecimento em áreas-chave da regeneração óssea e análise de dados genômicos. Atualmente, minhas principais linhas de pesquisa podem ser resumidas em cinco vertentes interconectadas:

+ #strong[Aspectos moleculares e epigenéticos da regeneração óssea]

  Investigação dos mecanismos moleculares, epigenéticos e de sinalização celular envolvidos na resposta de células osteogênicas e endoteliais a biomateriais, com ênfase em processos de adesão celular, remodelação da matriz extracelular, osteogênese e angiogênese.

+ #strong[Desenvolvimento de métodos computacionais e ferramentas para análise de biomateriais ósseos]

  Desenvolvimento de metodologias computacionais, softwares e pacotes em R voltados à análise integrada de dados transcriptômicos, espectrais e funcionais, visando a comparação, classificação e predição do desempenho biológico de biomateriais ósseos.

+ #strong[Análise de dados de sequenciamento de terceira geração e genômica funcional]

  Desenvolvimento e aplicação de pipelines analíticos para dados de sequenciamento de longa leitura, com foco em variantes estruturais, modificações epigenéticas e integração de dados ômicos, aplicados a estudos funcionais, forense, biomédicos e translacionais.

+ #strong[Métodos de identificação humana e fenotipagem forense baseados em DNA]

  Desenvolvimento e validação de abordagens computacionais e estatísticas para identificação humana, genotipagem e inferência fenotípica a partir de dados genômicos, incluindo aplicações em genética forense e populacional, com ênfase em dados de sequenciamento de nova e terceira geração.

+ #strong[Avaliação da osteoimunidade no desenvolvimento e na regeneração óssea]

  Investigação da interação entre o sistema imune e o tecido ósseo durante processos de desenvolvimento, reparo e regeneração, com foco na resposta inflamatória induzida por biomateriais, no papel de células imunes e mediadores inflamatórios, e na integração entre sinais imunológicos e vias osteogênicas.

== Rede de colaboração
<rede-de-colaboração>
A atuação em pesquisa desenvolvida ao longo da carreira tem sido fortemente sustentada por uma rede de colaborações interinstitucionais e, em alguns casos, internacionais, fundamentais para a consolidação e a ampliação das linhas de investigação. Essas parcerias têm possibilitado a integração de diferentes expertises, o desenvolvimento de projetos multidisciplinares, a coautoria de publicações científicas e a formação de recursos humanos, contribuindo de maneira consistente para a qualidade, o alcance e o impacto da produção científica. A seguir, são listados os principais colaboradores com os quais mantenho ou mantive projetos de pesquisa ativos.

#line(length: 50%, stroke: white)
- Prof.~Dr.~Willian Fernando Zambuzzi --- Instituto de Biociências de Botucatu, Universidade Estadual Paulista "Júlio de Mesquita Filho" (UNESP);

- Prof.~Dr.~Erick da Cruz Castelli --- Faculdade de Medicina de Botucatu, Universidade Estadual Paulista "Júlio de Mesquita Filho" (UNESP);

- Prof.~Dr.~Celso Teixeira Mendes Junior --- Faculdade de Filosofia, Ciências e Letras de Ribeirão Preto, Universidade de São Paulo (USP);

- Prof.~Dra. Silviene Fabiana de Oliveira --- Instituto de Biologia, Universidade de Brasília (UnB);

- Prof.~Dr.~Luis Antonio Justulin Junior --- Instituto de Biociências de Botucatu, Universidade Estadual Paulista "Júlio de Mesquita Filho" (UNESP);

- Prof.~Dr.~Rodrigo Augusto Foganholi da Silva --- Universidade Paulista (UNIP);

- Prof.~Dra. Denise Carletto Andia --- Universidade Paulista (UNIP);

- Prof.~Dr.~Lukasz Witek --- New York University (NYU), Estados Unidos;

- Dra. Flavia Amadeu de Oliveira --- Sanford Burnham Prebys Medical Discovery Institute, Estados Unidos;

- Prof.~Dr.~Miten Jain --- Northeastern University, Estados Unidos.

#line(length: 50%, stroke: white)
== Alinhamento com os Objetivos de Desenvolvimento Sustentável (ODS/ONU)
<alinhamento-com-os-objetivos-de-desenvolvimento-sustentável-odsonu>
As atividades de pesquisa desenvolvidas ao longo da minha trajetória acadêmica apresentam alinhamento consistente com os #link("https://brasil.un.org/pt-br/sdgs")[Objetivos de Desenvolvimento Sustentável (ODS)] definidos pela Organização das Nações Unidas, com destaque para o ODS 3 -- Saúde e Bem-Estar, o ODS 4 -- Educação de Qualidade e o ODS 9 -- Indústria, Inovação e Infraestrutura, que dialogam diretamente com minhas linhas de pesquisa e atuação acadêmica.

#quarto_super(
kind: 
"quarto-float-fig"
, 
caption: 
[
Objetivos de Desenvolvimento Sustentável (ODS) propostos pela Organização das Nações Unidas
]
, 
label: 
<fig-sdg>
, 
position: 
bottom
, 
supplement: 
"Figura"
, 
subrefnumbering: 
"1a"
, 
subcapnumbering: 
"(a)"
, 
[
#grid(columns: 3, gutter: 2em,
  [
#block[
#figure([
#box(image("img/ods03.png"))
], caption: figure.caption(
position: bottom, 
[
Saúde e Bem-Estar
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-sdg03>


]
],
  [
#block[
#figure([
#box(image("img/ods04.png"))
], caption: figure.caption(
position: bottom, 
[
Educação de Qualidade
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-sdg04>


]
],
  [
#block[
#figure([
#box(image("img/ods09.png"))
], caption: figure.caption(
position: bottom, 
[
Indústria, Inovação e Infraestrutura
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-sdg09>


]
],
)
]
)
#strong[ODS 3 -- Saúde e Bem-Estar]

As atividades de pesquisa desenvolvidas ao longo da minha trajetória contribuem para o ODS 3, ao promover abordagens orientadas por dados nas áreas da saúde e das ciências biomédicas. Por meio da integração de bioinformática, transcriptômica, epigenética e pesquisa em biomateriais, meus trabalhos apoiam o desenvolvimento e a avaliação de estratégias regenerativas, com ênfase na engenharia de tecido ósseo. O foco em modelos in vitro e em pipelines computacionais preditivos visa aprofundar a compreensão das interações célula--material e gerar biomarcadores robustos, contribuindo para soluções em saúde mais seguras, eficazes e sustentáveis.

#strong[ODS 4 -- Educação de Qualidade]

Em consonância com o ODS 4, atuo na promoção da educação de qualidade por meio da formação científica, capacitação técnica e desenvolvimento de recursos educacionais abertos. Desenvolvo e ministro #emph[workshops];, minicursos e materiais didáticos nas áreas de bioinformática, ciência de dados e práticas de pesquisa reprodutível. Ao enfatizar a alfabetização computacional e a análise crítica de dados, essas ações contribuem para a formação de estudantes e pesquisadores altamente qualificados, fortalecendo processos de aprendizagem inclusivos e contínuos em ciência e tecnologia.

#strong[ODS 9 -- Indústria, Inovação e Infraestrutura]

Minha atuação também se alinha ao ODS 9, ao contribuir para a inovação científica e o fortalecimento da infraestrutura digital de pesquisa. Desenvolvo fluxos computacionais escaláveis, estratégias analíticas baseadas em aprendizado de máquina e recursos de dados interoperáveis que integram informações físicas, químicas e biológicas. Essas iniciativas fortalecem a infraestrutura de pesquisa e estimulam a inovação na interface entre biologia, ciência dos materiais e ciência de dados, favorecendo a geração eficiente de conhecimento e a potencial tradução de avanços científicos em aplicações tecnológicas e industriais.

== Auxílio de Pesquisa
<auxílio-de-pesquisa>
Nesta seção são apresentados os auxílios de pesquisa dos quais participei como pesquisador integrante ou colaborador, em projetos financiados por agências de fomento nacionais e internacionais. Embora não figure como pesquisador responsável, minha atuação nesses projetos envolveu contribuições científicas diretas para o desenvolvimento das atividades de pesquisa, a execução experimental e analítica, a produção de resultados e publicações, bem como a formação de recursos humanos. A participação nesses auxílios foi fundamental para a consolidação das linhas de pesquisa desenvolvidas e para o fortalecimento de colaborações interinstitucionais.

+ Genômica funcional em tecido epitelial de brasileiros miscigenados utilizando sequenciamento long-read Oxford Nanopore: análiseintegrada da diversidade genética e expressão gênica para a predição da pigmentação da pele e de idade epigenética

  Descrição: Descrição: Edital Universal CNPq. Vigência: 23/11/2023 a 22/11/2026. Processo 408084/2023-5. Auxílio financeiro: R\$207.500,00..

  Situação: Em andamento; Natureza: Pesquisa.

  Alunos envolvidos: Doutorado: (3) .

  Integrantes: Silviene Fabiana de Oliveira - Integrante / Celso Mendes Júnior - Coordenador / Erick da Cruz Castelli - Integrante / Marcel Rodrigues Ferreira - Integrante.

+ Validação e desenvolvimento de painéis de fenotipagem forense e ancestralidade biogeográfica como ferramenta auxiliar na genética forense, em especial para a busca de pessoas desaparecidas no Brasil

  Descrição: Chamada CNPq/MCTI/FNDCT N 44/2024 - UNIVERSAL (Faixa A). Vigência: 2025 a 2028. Processo 409907/2025-1. Auxílio financeiro: R\$140.000,00.. \
  Situação: Em andamento; Natureza: Pesquisa. \
  \
  Integrantes: Celso Teixeira Mendes Junior - Integrante / Aguinaldo Luiz Simões - Integrante / Silviene Fabiana de Oliveira - Coordenador / Thássia Mayra Telles Carratto - Integrante / Ronaldo Carneiro da Silva Junior - Integrante / Marcel Rodrigues Ferreira - Integrante / Bruno Trindade - Integrante / Diana Vilas Boas e Silva - Integrante. \
  Financiador(es): Conselho Nacional de Desenvolvimento Científico e Tecnológico - Auxílio financeiro.

== Publicações: Artigos Completos Aceitos para Publicação e Publicados em Periódicos Internacionais, Capítulos de Livros Publicados, e Trabalhos Completos Publicados em Anais de Congressos
<publicações-artigos-completos-aceitos-para-publicação-e-publicados-em-periódicos-internacionais-capítulos-de-livros-publicados-e-trabalhos-completos-publicados-em-anais-de-congressos>
A seguir, apresentam-se, em ordem cronológica de publicação, os artigos científicos completos publicados em periódicos internacionais, bem como capítulos de livros e trabalhos completos publicados em anais de congressos. Para cada produção, são informados: autores, título do trabalho, nome do periódico (ou livro/anais), volume, número, páginas e ano de publicação. O DOI é apresentado na forma de hiperlink, permitindo o acesso direto à versão online do artigo, e o PMID é informado quando disponível.

+ Alvarez TM, Liberato MV, Cairo JP, Paixão DA, Campos BM, #underline[#strong[Ferreira MR];];, Almeida RF, Pereira IO, Bernardes A, Ematsu GC, Chinaglia M, Polikarpov I, de Oliveira Neto M, Squina FM. #emph[A Novel Member of GH16 Family Derived from Sugarcane Soil Metagenome];. Appl Biochem Biotechnol. 2015 Sep;177(2):304-17. doi: #link("https://www.doi.org/10.1007/s12010-015-1743-7")[10.1007/s12010-015-1743-7];. Epub 2015 Aug 5. PMID: 26242386.

+ Bezerra F, #underline[#strong[Ferreira MR];];, Fontes GN, da Costa Fernandes CJ, Andia DC, Cruz NC, da Silva RA, Zambuzzi WF. #emph[Nano hydroxyapatite-blasted titanium surface affects pre-osteoblast morphology by modulating critical intracellular pathways];. Biotechnol Bioeng. 2017 Aug;114(8):1888-1898. doi: #link("https://www.doi.org/10.1002/bit.26310")[10.1002/bit.26310];. Epub 2017 Jun 7. PMID: 28401535.

+ Fernandes CJC, Bezerra F, #underline[#strong[Ferreira MR];];, Andrade AFC, Pinto TS, Zambuzzi WF. #emph[Nano hydroxyapatite-blasted titanium surface creates a biointerface able to govern Src-dependent osteoblast metabolism as prerequisite to ECM remodeling];. Colloids Surf B Biointerfaces. 2018 Mar 1;163:321-328. doi: #link("https://www.doi.org/10.1016/j.colsurfb.2017.12.049")[10.1016/j.colsurfb.2017.12.049];. Epub 2017 Dec 28. PMID: 29329077.

+ da Costa Fernandes CJ, #underline[#strong[Ferreira MR];];, Bezerra FJB, Zambuzzi WF. #emph[Zirconia stimulates ECM-remodeling as a prerequisite to pre-osteoblast adhesion/proliferation by possible interference with cellular anchorage];. J Mater Sci Mater Med. 2018 Mar 26;29(4):41. doi: #link("https://www.doi.org/10.1007/s10856-018-6041-9")[10.1007/s10856-018-6041-9];. PMID: 29582191.

+ da Silva RA, de Camargo Andrade AF, da Silva Feltran G, Fernandes CJDC, de Assis RIF, #underline[#strong[Ferreira MR];];, Andia DC, Zambuzzi WF. #emph[The role of triiodothyronine hormone and mechanically-stressed endothelial cell paracrine signalling synergism in gene reprogramming during hBMSC-stimulated osteogenic phenotype in vitro];. Mol Cell Endocrinol. 2018 Dec 15;478:151-167. doi: #link("https://www.doi.org/10.1016/j.mce.2018.08.008")[10.1016/j.mce.2018.08.008];. Epub 2018 Aug 22. PMID: 30142372.

+ da Silva Feltran G, da Costa Fernandes CJ, #underline[#strong[Rodrigues Ferreira M];];, Kang HR, de Carvalho Bovolato AL, de Assis Golim M, Deffune E, Koh IHJ, Constantino VRL, Zambuzzi WF. #emph[Sonic hedgehog drives layered double hydroxides-induced acute inflammatory landscape];. Colloids Surf B Biointerfaces. 2019 Feb 1;174:467-475. doi: #link("https://www.doi.org/10.1016/j.colsurfb.2018.11.051")[10.1016/j.colsurfb.2018.11.051];. Epub 2018 Nov 22. PMID: 30497008.

+ Machado MIP, Gomes AM, #underline[Rodrigues MF];#footnote[Houve um erro na submissão, resultando na inversão dos sobrenomes. Portanto, o nome correto é Marcel Rodrigues Ferreira. Caso queira confirmar a veracidade desse artigo, o professor Dr.~Willian Zambuzzi (#link("mailto:w.zambuzzi@unesp.br")[w.zambuzzi\@unesp.br];) pode ser consultado.] , Silva Pinto T, da Costa Fernandes CJ, Bezerra FJ, Zambuzzi WF. #emph[Cobalt-chromium-enriched medium ameliorates shear-stressed endothelial cell performance];. J Trace Elem Med Biol. 2019 Jul;54:163-171. doi: #link("https://www.doi.org/10.1016/j.jtemb.2019.04.012")[10.1016/j.jtemb.2019.04.012];. Epub 2019 Apr 24. PMID: 31109607.

+ da S Feltran G, Bezerra F, da Costa Fernandes CJ, #underline[#strong[Ferreira MR];];, Zambuzzi WF. #emph[Differential inflammatory landscape stimulus during titanium surfaces obtained osteogenic phenotype];. J Biomed Mater Res A. 2019 Aug;107(8):1597-1604. doi: #link("https://www.doi.org/10.1002/jbm.a.36673")[10.1002/jbm.a.36673];. Epub 2019 Apr 9. PMID: 30884166.

+ da Silva RA, Fuhler GM, Janmaat VT, da C Fernandes CJ, da Silva Feltran G, Oliveira FA, Matos AA, Oliveira RC, #underline[#strong[Ferreira MR];];, Zambuzzi WF, Peppelenbosch MP. #emph[HOXA cluster gene expression during osteoblast differentiation involves epigenetic contro];l. Bone. 2019 Aug;125:74-86. doi: #link("https://www.doi.org/10.1016/j.bone.2019.04.026")[10.1016/j.bone.2019.04.026];. Epub 2019 May 1. PMID: 31054377.

+ da Silva RA, #underline[#strong[Ferreira MR];];, Gomes AM, Zambuzzi WF. #emph[LncRNA HOTAIR is a novel endothelial mechanosensitive gene];. J Cell Physiol. 2020 May;235(5):4631-4642. doi: #link("https://www.doi.org/10.1002/jcp.29340")[10.1002/jcp.29340];. Epub 2019 Oct 21. PMID: 31637716.

+ Gomes OP, Feltran GS, #underline[#strong[Ferreira MR];];, Albano CS, Zambuzzi WF, Lisboa-Filho PN. #emph[A novel BSA immobilizing manner on modified titanium surface ameliorates osteoblast performance];. Colloids Surf B Biointerfaces. 2020 Jun;190:110888. doi: #link("https://www.doi.org/10.1016/j.colsurfb.2020.110888")[10.1016/j.colsurfb.2020.110888];. Epub 2020 Feb 20. PMID: 32114272.

+ da Silva RA, da Silva Feltran G, #underline[#strong[Ferreira MR];];, Wood PF, Bezerra F, Zambuzzi WF. #emph[The Impact of Bioactive Surfaces in the Early Stages of Osseointegration: An \<i\>In Vitro\</i\> Comparative Study Evaluating the HAnano® and SLActive® Super Hydrophilic Surfaces];. Biomed Res Int. 2020 Sep 13;2020:3026893. doi: #link("https://www.doi.org/10.1155/2020/3026893")[10.1155/2020/3026893];. PMID: 33005686; PMCID: PMC7509554.

+ #underline[#strong[Ferreira MR];];, Milani R, Rangel EC, Peppelenbosch M, Zambuzzi W. #emph[OsteoBLAST: Computational Routine of Global Molecular Analysis Applied to Biomaterials Development];. Front Bioeng Biotechnol. 2020 Oct 8;8:565901. doi: #link("https://www.doi.org/10.3389/fbioe.2020.565901")[10.3389/fbioe.2020.565901];. PMID: 33117780; PMCID: PMC7578266.

+ Assis RIF, Feltran GDS, Silva MES, Palma ICDR, Rovai ES, Miranda TB, #underline[#strong[Ferreira MR];];, Zambuzzi WF, Birbrair A, Andia DC, da Silva RA. #emph[Non-coding RNAs repressive role in post-transcriptional processing of RUNX2 during the acquisition of the osteogenic phenotype of periodontal ligament mesenchymal stem cells];. Dev Biol. 2021 Feb;470:37-48. doi: #link("https://www.doi.org/10.1016/j.ydbio.2020.10.012")[10.1016/j.ydbio.2020.10.012];. Epub 2020 Nov 2. PMID: 33152274.

+ #underline[#strong[Ferreira MR];];, Santos GA, Biagi CA, Silva Junior WA, Zambuzzi WF. #emph[GSVA score reveals molecular signatures from transcriptomes for biomaterials comparison];. J Biomed Mater Res A. 2021 Jun;109(6):1004-1014. doi: #link("https://www.doi.org/10.1002/jbm.a.37090")[10.1002/jbm.a.37090];. Epub 2020 Sep 9. PMID: 32820608.

+ #underline[#strong[Ferreira MR];];, Zambuzzi WF. #emph[Platelet microparticles load a repertory of miRNAs programmed to drive osteogenic phenotype];. J Biomed Mater Res A. 2021 Aug;109(8):1502-1511. doi: #link("https://www.doi.org/10.1002/jbm.a.37140")[10.1002/jbm.a.37140];. Epub 2020 Dec 10. PMID: 33258548.

+ Pinto TS, Martins BR, #underline[#strong[Ferreira MR];];, Bezerra F, Zambuzzi WF. #emph[Nanohydroxyapatite-Blasted Bioactive Surface Drives Shear-Stressed Endothelial Cell Growth and Angiogenesis];. Biomed Res Int. 2022 Feb 23;2022:1433221. doi: #link("https://www.doi.org/10.1155/2022/1433221")[10.1155/2022/1433221];. PMID: 35252440; PMCID: PMC8890866.

+ Franco Cairo JPL, Mandelli F, Tramontina R, Cannella D, Paradisi A, Ciano L, #underline[#strong[Ferreira MR];];, Liberato MV, Brenelli LB, Gonçalves TA, Rodrigues GN, Alvarez TM, Mofatto LS, Carazzolle MF, Pradella JGC, Paes Leme AF, Costa-Leonardo AM, Oliveira-Neto M, Damasio A, Davies GJ, Felby C, Walton PH, Squina FM. #emph[Oxidative cleavage of polysaccharides by a termite-derived \<i\>superoxide dismutase\</i\> boosts the degradation of biomass by glycoside hydrolases];. Green Chem. 2022 May 12;24(12):4845-4858. doi: #link("https://www.doi.org/10.1039/d1gc04519a")[10.1039/d1gc04519a];. PMID: 35813357; PMCID: PMC9208272.

+ da C Fernandes CJ, da Silva RAF, de Almeida GS, #underline[#strong[Ferreira MR];];, de Morais PB, Bezerra F, Zambuzzi WF. Epigenetic #emph[Differences Arise in Endothelial Cells Responding to Cobalt-Chromium];. J Funct Biomater. 2023 Feb 26;14(3):127. doi: #link("https://www.doi.org/10.3390/jfb14030127")[10.3390/jfb14030127];. PMID: 36976051; PMCID: PMC10052026.

+ Fernandes CJDC, da Silva RAF, Wood PF, #underline[#strong[Ferreira MR];];, de Almeida GS, de Moraes JF, Bezerra FJ, Zambuzzi WF. #emph[Titanium-Enriched Medium Promotes Environment-Induced Epigenetic Machinery Changes in Human Endothelial Cells];. J Funct Biomater. 2023 Feb 27;14(3):131. doi: #link("https://www.doi.org/10.3390/jfb14030131")[10.3390/jfb14030131];. PMID: 36976055; PMCID: PMC10055987.

+ da Costa Fernandes CJ, #underline[#strong[Ferreira MR];];, Zambuzzi WF. #emph[Cyclopamine targeting hedgehog modulates nuclear control of the osteoblast activity];. Cells Dev. 2023 Jun;174:203836. doi: #link("https://www.doi.org/10.1016/j.cdev.2023.203836")[10.1016/j.cdev.2023.203836];. Epub 2023 Mar 25. PMID: 36972848.

+ Amadeu de Oliveira F, Tokuhara CK, Veeriah V, Domezi JP, Santesso MR, Cestari TM, Ventura TMO, Matos AA, Dionísio T, #underline[#strong[Ferreira MR];];, Ortiz RC, Duarte MAH, Buzalaf MAR, Ponce JB, Sorgi CA, Faccioli LH, Buzalaf CP, de Oliveira RC. The #emph[Multifarious Functions of Leukotrienes in Bone Metabolism];. J Bone Miner Res. 2023 Aug;38(8):1135-1153. doi: #link("https://www.doi.org/10.1002/jbmr.4867")[10.1002/jbmr.4867];. Epub 2023 Jun 29. PMID: 37314430.

+ Carvalho LB, Dos Santos Sanna PL, Dos Santos Afonso CC, Bondan EF, da Silva Feltran G, #underline[#strong[Ferreira MR];];, Birbrair A, Andia DC, Latini A, Foganholi da Silva RA. #emph[MicroRNA biogenesis machinery activation and lncRNA and REST overexpression as neuroprotective responses to fight inflammation in the hippocampus];. J Neuroimmunol. 2023 Sep 15;382:578149. doi: #link("https://doi.org/10.1016/j.jneuroim.2023.578149")[10.1016/j.jneuroim.2023.578149];. Epub 2023 Jul 18. PMID: 37481910.

+ Bergamo ETP, Balderrama ÍF, #underline[#strong[Ferreira MR];];, Spielman R, Slavin BV, Torroni A, Tovar N, Nayak VV, Slavin BR, Coelho PG, Witek L. #emph[Osteogenic differentiation and reconstruction of mandible defects using a novel resorbable membrane: An in vitro and in vivo experimental study];. J Biomed Mater Res B Appl Biomater. 2023 Nov;111(11):1966-1978. doi: #link("https://doi.org/10.1002/jbm.b.35299")[10.1002/jbm.b.35299];. Epub 2023 Jul 20. PMID: 37470190.

+ de Almeida GS, #underline[#strong[Ferreira MR];];, da Costa Fernandes CJ, Suter LC, Carra MGJ, Correa DRN, Rangel EC, Saeki MJ, Zambuzzi WF. #emph[Development of cobalt (Co)-doped monetites for bone regeneration];. J Biomed Mater Res B Appl Biomater. 2024 Jan;112(1):e35319. doi: #link("https://www.doi.org/10.1002/jbm.b.35319")[10.1002/jbm.b.35319];. Epub 2023 Aug 23. PMID: 37610175.

+ de Almeida GS, #underline[#strong[Ferreira MR];];, Fernandes CC Jr, de Biagi CAO Jr, Silva WA Jr, Rangel EC, Lisboa-Filho PN, Zambuzzi WF. #emph[Combination of in silico and cell culture strategies to predict biomaterial performance: Effects of sintering temperature on the biological properties of hydroxyapatite];. J Biomed Mater Res B Appl Biomater. 2024 Feb;112(2):e35389. doi: #link("https://www.doi.org/10.1002/jbm.b.35389")[10.1002/jbm.b.35389];. PMID: 38356168.

+ Lemes Dos Santos Sanna P, Bernardes Carvalho L, Cristina Dos Santos Afonso C, de Carvalho K, Aires R, Souza J, #underline[#strong[Rodrigues Ferreira M];];, Birbrair A, Martha Bernardi M, Latini A, Foganholi da Silva RA. #emph[Adora2A downregulation promotes caffeine neuroprotective effect against LPS-induced neuroinflammation in the hippocampus];. Brain Res. 2024 Jun 15;1833:148866. doi: #link("https://www.doi.org/10.1016/j.brainres.2024.148866")[10.1016/j.brainres.2024.148866];. Epub 2024 Mar 15. PMID: 38494098.

+ da Silva Feltran G, Augusto da Silva R, da Costa Fernandes CJ, #underline[#strong[Ferreira MR];];, Dos Santos SAA, Justulin Junior LA, Del Valle Sosa L, Zambuzzi WF. #emph[Vascular smooth muscle cells exhibit elevated hypoxia-inducible Factor-1α expression in human blood vessel organoids, influencing osteogenic performance];. Exp Cell Res. 2024 Jul 15;440(2):114136. doi: #link("https://www.doi.org/10.1016/j.yexcr.2024.114136")[10.1016/j.yexcr.2024.114136];. Epub 2024 Jun 22. PMID: 38909881.

+ Fernandes CJC, Silva RA, #underline[#strong[Ferreira MR];];, Fuhler GM, Peppelenbosch MP, van der Eerden BC, Zambuzzi WF. #emph[Vascular smooth muscle cell-derived exosomes promote osteoblast-to-osteocyte transition via β-catenin signaling];. Exp Cell Res. 2024 Sep 1;442(1):114211. doi: #link("https://www.doi.org/10.1016/j.yexcr.2024.114211")[10.1016/j.yexcr.2024.114211];. Epub 2024 Aug 14. PMID: 39147261.

+ Naia Fioretto M, Maciel FA, Barata LA, Ribeiro IT, Basso CBP, #underline[#strong[Ferreira MR];];, Dos Santos SAA, Mattos R, Baptista HS, Portela LMF, Padilha PM, Felisbino SL, Scarano WR, Zambrano E, Justulin LA. #emph[Impact of maternal protein restriction on the proteomic landscape of male rat lungs across the lifespan];. Mol Cell Endocrinol. 2024 Oct 1;592:112348. doi: #link("https://www.doi.org/10.1016/j.mce.2024.112348")[10.1016/j.mce.2024.112348];. Epub 2024 Aug 31. PMID: 39218056.

+ #underline[#strong[Ferreira MR];];, Carratto TMT, Frontanilla TS, Bonadio RS, Jain M, de Oliveira SF, Castelli EC, Mendes-Junior CT. #emph[Advances in forensic genetics: Exploring the potential of long read sequencing];. Forensic Sci Int Genet. 2025 Jan;74:103156. doi: #link("https://www.doi.org/10.1016/j.fsigen.2024")[10.1016/j.fsigen.2024];.103156. Epub 2024 Oct 10. PMID: 39427416.

+ L Urbano Pagan, M Gatto, #underline[#strong[MR Ferreira];];, MJ Gomes, JPG Oliveira, GAF Mota, FC Damatto, LM Souza, ACC Santos, EA Rodrigues, PA Borim, DHS Campos, MP Okoshi, K Okoshi. #emph[Effects of empagliflozin on myocardial transcriptome in rats with aortic stenosis-induced heart failure];. European Heart Volume 45, Issue Supplement\_1, October 2024, ehae666.1829. doi: #link("https://doi.org/10.1093/eurheartj/ehae666.1829")[10.1093/eurheartj/ehae6]

+ Castelli EC, Pereira RN, Paes GS, Andrade HS, #underline[#strong[Ferreira MR];];, de Freitas Santos ÍS, Vince N, Pollock NR, Norman PJ, Meyer D. #emph[kir-mapper: A Toolkit for Killer-Cell Immunoglobulin-Like Receptor (KIR) Genotyping From Short-Read Second-Generation Sequencing Data];. HLA. 2025 Mar;105(3):e70092. doi: #link("https://www.doi.org/")[10.1111/tan.70092];. PMID: 40095784; PMCID: PMC11927768.

+ Zambuzzi WF, #underline[#strong[Ferreira MR];];. #emph[Dynamic ion-releasing biomaterials actively shape the microenvironment to enhance healing];. J Trace Elem Med Biol. 2025 Jun;89:127657. doi: #link("https://www.doi.org/10.1016/j.jtemb.2025.127657")[10.1016/j.jtemb.2025.127657];. Epub 2025 Apr 17. PMID: 40250222.

+ Zambuzzi WF, #underline[#strong[Ferreira MR];];, Wang Z, Peppelenbosch MP. #emph[A Biochemical View on Intermittent Fasting's Effects on Human Physiology-Not Always a Beneficial Strategy];. Biology (Basel). 2025 Jun 9;14(6):669. doi: #link("https://www.doi.org/10.3390/biology14060669")[10.3390/biology14060669];. PMID: 40563920; PMCID: PMC12190167.

+ #underline[#strong[Ferreira MR];];, Feltran GDS, Gomes AM, Vieira JCS, Santana GG, Silva MA, Santos EAAD, Zambuzzi WF. #emph[Mesenchymal Stem Cell Differentiation Induced by Lyophilized PRP During Early Osteogenesis];. Cell Biol Int. 2026 Jan;50(1):e70101. doi: #link("https://www.doi.org/10.1002/cbin.70101")[10.1002/cbin.70101];. Epub 2025 Nov 13. PMID: 41230788.

+ Fernandes CJC, Foganholi da Silva RA, #underline[#strong[Ferreira MR];];, Zambuzzi WF. Venous Endothelial Cells Promote Osteoblast Differentiation More Effectively Than Arterial Cells via TGF-β/BMP9 and Notch Pathway-Related Gene Expression. Cell Biochemistry and Function. 2026;44:1--14. doi:#link("https://doi.org/10.1002/cbf.70160.")[10.1002/cbf.70160];.

+ Suter LC, de Almeida GS, dos Santos MLP, Carra MGJ, #underline[#strong[Ferreira MR];];, Saeki MJ, Zambuzzi WF. Cobalt-Doped Biphasic Calcium Phosphate Orchestrates Osteogenesis-Angiogenesis Signals via Hypoxia-Mimetic Signaling. J Biomed Mater Res A. 2026;114(4):e70070. doi: #link("www.doi.org/10.1002/jbm.a.70070")[10.1002/jbm.a.70070];.

+ Fioretto MN, #underline[#strong[Ferreira MR];];, Caxali GH, de Souza PV, Maciel FA, Ribeiro IT, Barata LA, Vieira ALS, Pires MP, Lemos LS, Mattos R, Delella FK, Scarano WR, Zambrano E, Justulin LA. Omics-based molecular signatures of adrenal, kidney, and lung development in male rat offspring exposed to maternal protein restriction. Clin Nutr. 2026;XX:106656. doi: #link("www.doi.org/10.1016/j.clnu.2026.106656")[10.1016/j.clnu.2026.106656];.

+ Alvarez DAN, Ribeiro IT, Fioretto MN, Pires MP, Barata LA, Maciel FA, Portela LMF, Mattos R, Baptista HS, Vitali PM, Felipe VAA, #underline[#strong[Ferreira MR];];, Zambrano E, Boer PA, Justulin LA. Renal proteomics of male offspring exposed to maternal protein restriction: molecular, epigenetic, and nephron-specific signatures of metabolic programming. J Physiol Biochem. 2026;82:48. doi: #link("www.doi.org/10.1007/s13105-026-01189-9")[10.1007/s13105-026-01189-9];.

== Análise Estatística das Publicações
<análise-estatística-das-publicações>
+ Número de publicações: 40.

+ Número de artigos completos em periódicos: 39.

+ Número de citações: 632 (Google Scholar), 540 (ResearchGate), 502 (Scopus), 479 (ResearcherID).

+ Média de citações: 18,06 (Google Scholar), 15,43 (ResearchGate), 14,34 (Scopus), 13,31 (ResearcherID).

+ h-index: 14 (Google Scholar), 13 (ResearchGate), 13 (Scopus), 12 (ResearcherID).

== Contribuições Científicas
<contribuições-científicas>
Uma das vertentes centrais da minha atuação científica tem sido o desenvolvimento de ferramentas computacionais voltadas à análise, integração e interpretação de dados biológicos complexos, com ênfase em transcriptômica, biomateriais e ciência de dados reprodutível. Essas iniciativas surgiram da necessidade de traduzir questões biológicas e experimentais em soluções metodológicas acessíveis, padronizadas e reutilizáveis pela comunidade científica.

Nesse contexto, desenvolvi e registrei o software #strong[OsteoCLUST] -- Aplicativo para Análise e Comparação de Biomateriais Ósseos com Base em Dados Transcriptômicos (Processo nº BR512024004865-0), cuja titularidade pertence à Universidade Estadual Paulista "Júlio de Mesquita Filho". O #strong[OsteoCLUST] integra rotinas estatísticas e visualizações interativas para a comparação global de assinaturas moleculares associadas à resposta celular a biomateriais, utilizando dados transcriptômicos. O aplicativo foi implementado utilizando as linguagens R, HTML, JavaScript e CSS, refletindo uma abordagem interdisciplinar entre análise de dados e desenvolvimento de interfaces amigáveis ao usuário.

Anteriormente, participei do desenvolvimento e registro do software #strong[previewDeconv] -- um aplicativo para pré-visualização de bandas deconvoluídas (Processo nº BR512023000985-7), também com titularidade da UNESP. Esse aplicativo, implementado em C++, R e HTML, foi concebido para auxiliar na análise e interpretação de dados espectrais, contribuindo para a padronização de etapas analíticas em estudos físico-químicos e de biomateriais.

Além dos softwares registrados, sou autor do pacote #strong[tidyspec] (M. Ferreira 2025), publicado no repositório oficial do #link("https://cran.r-project.org/")[CRAN];#footnote[O CRAN, ou #emph[Comprehensive R Archive Network];, é um repositório online que armazena pacotes de software para a linguagem de programação R. Ele é mantido por uma comunidade global de desenvolvedores e usuários de R, e permite que os usuários acessem e baixem pacotes de software que expandem as funcionalidades básicas do R. O CRAN é essencial para o ecossistema R, pois facilita a distribuição de pacotes e garante que eles sejam de código aberto, documentados e testados.];, voltado à organização, processamento e análise de dados espectrais no ambiente R, seguindo princípios do ecossistema tidyverse. Esse pacote tem sido utilizado tanto em minhas pesquisas quanto em atividades didáticas, contribuindo para a formação de estudantes em análise de dados reprodutível.

#line(length: 50%, stroke: white)
#block[
#heading(
level: 
4
, 
numbering: 
none
, 
[
Aplicativo para Análise e Comparação de Biomateriais Ósseos com Base em Dados Transcriptômicos (OsteoCLUST)
]
)
]
#strong[Processo Nº:] BR512024004865-0

#strong[Título:] Aplicativo para Análise e Comparação de Biomateriais Ósseos com Base em Dados Transcriptômicos

#strong[Data de criação:] 31/07/2024

#strong[Titular(es):] UNIVERSIDADE ESTADUAL PAULISTA JULIO DE MESQUITA FILHO

#strong[Autor(es):] MARCEL RODRIGUES FERREIRA; WILLIAN FERNANDO ZAMBUZZI; MATHEUS AMARAL SILVA

#strong[Linguagem:] HTML; JAVA SCRIPT; CSS; R

#strong[Campo de aplicação:] BL-01; BL-02; SD-09; SD-11

#strong[Tipo de programa:] AP-01

#strong[Algoritmo hash:] SHA-512

#strong[Resumo digital hash:] cd598a23d0c6ff8bdd0135060116bc5066aed84dd6252cb47831bacf4656c3f8a90ae94c7513addd572c91c20aab4140e2 4465caa515da6e966d0baf742002a0

#strong[Expedido em:] 17/12/2024

#line(length: 50%)
#block[
#heading(
level: 
4
, 
numbering: 
none
, 
[
previewDeconv: um aplicativo para pré-visualização de bandas deconvoluídas Data de criação
]
)
]
#strong[Processo Nº:] BR512023000985-7

#strong[Título:] previewDeconv: um aplicativo para pré-visualização de bandas deconvoluídas

#strong[Data de criação:] 13/09/2021

#strong[Titular(es):] UNIVERSIDADE ESTADUAL PAULISTA JULIO DE MESQUITA FILHO

#strong[Autor(es):] WILLIAN FERANDO ZAMBUZZI; MARCEL RODRIGUES FERREIRA

#strong[Linguagem:] C++; HTML; R

#strong[Campo de aplicação:] FQ-01; FQ-06; FQ-14; FQ-17

#strong[Tipo de programa:] AP-01

#strong[Algoritmo hash:] SHA-512

#strong[Resumo digital hash:]

58c79b6c8e6d67cfbccb7a4a357c1ae895a9d25b5eb310a512655f1a7fa46257f826b0fe75917085af0e322e31f00e855f8d ef4c642d0c8f260ddd051143ba9b

#strong[Expedido em:] 18/04/2023

#line(length: 50%)
#block[
#heading(
level: 
4
, 
numbering: 
none
, 
[
Resumo:
]
)
]
- Softwares registrados: #emph[previewDeconv] e #emph[OsteoCLUST] ;

- Pacotes de R publicados no CRAN: #emph[tidyspec] (M. Ferreira 2025);

- Softwares sem registros publicados em artigos científicos: #emph[kir-mapper] (Castelli et al. 2025);

#pagebreak()
= Atividades de Extensão e Serviços à Comunidade
<sec-7>
As atividades de extensão e os serviços prestados à comunidade constituem um eixo estruturante da minha trajetória acadêmica e profissional, estando presentes de forma contínua desde o início da formação universitária. Ao longo dos anos, tenho participado ativamente de iniciativas voltadas à democratização do acesso ao conhecimento, à formação educacional e científica de estudantes e à interação direta entre a universidade e a sociedade. Destacam-se, nesse contexto, os projetos de extensão relacionados a cursinhos pré-vestibulares e pré-universitários, nos quais atuei majoritariamente como responsável, evidenciando um compromisso duradouro com ações de impacto social e educacional.

Paralelamente, minha atuação em extensão também se manifesta na participação em bancas examinadoras, na organização de eventos científicos e acadêmicos, na oferta de cursos, seminários e palestras, bem como no exercício de atividades de assessoramento e avaliação científica para periódicos nacionais e internacionais. Conjuntamente, essas ações refletem uma compreensão ampliada do papel do docente universitário, que articula ensino, pesquisa e extensão, contribuindo não apenas para a formação acadêmica qualificada, mas também para o fortalecimento do vínculo entre a universidade, a comunidade científica e a sociedade em geral.

== Projetos de extensão
<projetos-de-extensão>
+ #strong[Cursinho Pré Universitário Atena]

  Situação: Concluído Natureza: Projeto de extensão. Integrantes: Marcel Rodrigues Ferreira (Responsável);

+ #strong[Cursinho Pré Vestibular do Instituto de Biociências de Botucatu] (2015 - 2017)

  Situação: Concluído Natureza: Projeto de extensão. Integrantes: #underline[#strong[Marcel Rodrigues Ferreira];] (Responsável); ; Célio Junior da Costa Fernandes;

+ #strong[Nucleon JR] (2013 - 2014 )

  Descrição: Empresa junior dos alunos do curso de Física Médica do Instituto de Biociências de Botucatu/UNESP. Situação: Concluído Natureza: Projeto de extensão. Integrantes: #underline[#strong[Marcel Rodrigues Ferreira];] (Responsável); ; Fernanda Nascimento Moura;

+ #strong[Cursinho CAVJ/IB] (2012-2013).

  Situação: Concluído Natureza: Projeto de extensão. Integrantes: #underline[#strong[Marcel Rodrigues Ferreira];] (Responsável);

+ #strong[Cursinho Desafio] (2011-2011).

  Descrição: Cursinho pré vestibular destinado a estudantes de Escolas Públicas. Conta com a coordenação e participação de estudantes dos cursos da Unesp de Botucatu. Situação: Concluído Natureza: Projeto de extensão. Integrantes: #underline[#strong[Marcel Rodrigues Ferreira];];; Raíssa Pierre Carvalho (Responsável)

== Participação em Bancas Examinadoras e Julgadoras
<participação-em-bancas-examinadoras-e-julgadoras>
Sempre que solicitado, tenho participado na composição de bancas examinadoras de trabalho de conclusão de curso, qualificações de mestrado e doutorado, defesas de mestrado e doutorado, etc. Abaixo, estão listadas as participações em bancas examinadoras como membro titular das comissões:

+ #strong[06-02-2023] Membro da Banca Examinadora do TRABALHO DE CONCLUSÃO DE CURSO de MARIA GABRIELA JACHETO CARRA, discente do curso de Física Médica, Bacharelado;

+ #strong[09-03-2023] Membro da Banca Examinadora do TRABALHO DE CONCLUSÃO DE CURSO de ALLINE REGONATTI ARAUJO, discente do curso de Física Médica, Bacharelado;

+ #strong[30-08-2023] Membro da Comissão Examinadora da DEFESA DE TESE de ANDERSON MOREIRA GOMES, discente regular do Programa de Pós-Graduação em Biotecnologia, Curso de Doutorado;

+ #strong[31-10-2023] Membro da Banca Examinadora do TRABALHO DE CONCLUSÃO DE CURSO de CARLA CRISTINA ALBERTINI, discente do curso de Engenharia de Bioprocessos e Biotecnologia, Bacharelado;

+ #strong[31-10-2023] Membro da Banca Examinadora do TRABALHO DE CONCLUSÃO DE CURSO de PAULA BERTIN DE MORAIS, discente do curso de Engenharia de Bioprocessos e Biotecnologia, Bacharelado;

+ #strong[08-12-2023] Membro da Banca Examinadora do TRABALHO DE CONCLUSÃO DE CURSO de JÚLIA BUCCI, discente do curso de Física Médica, Bacharelado;

+ #strong[04-07-2024] Membro da Banca Examinadora do TRABALHO DE CONCLUSÃO DE CURSO de THAMIRES PRAZERES BARBOZA, discente do curso de Engenharia de Bioprocessos e Biotecnologia, Bacharelado;

+ #strong[30-10-2024] Membro da Banca Examinadora do TRABALHO DE CONCLUSÃO DE CURSO de CARLOS HENRIQUE SILVA SIMÕES, discente do curso de Engenharia de Bioprocessos e Biotecnologia, Bacharelado;

+ #strong[27-02-2025] Membro da Comissão Examinadora da DEFESA DE DISSERTAÇÃO de RENATO MATTOS, discente regular do Programa de Pós-Graduação em Biologia Geral e Aplicada, Curso de Mestrado Acadêmico;

+ #strong[17-06-2025] Membro da Banca Examinadora do TRABALHO DE CONCLUSÃO DE CURSO de LUCIANA MARINO BORALI, discente do curso de Engenharia de Bioprocessos e Biotecnologia, Bacharelado;

+ #strong[30-09-2025] Membro da Comissão Examinadora do Exame de QUALIFICAÇÃO de GABRIEL HENRIQUE CAXALI, discente regular do Programa de Pós-Graduação em Ciências Biológicas (Genética), Curso de Doutorado;

+ #strong[04-11-2025] Membro da Comissão Examinadora do Exame de QUALIFICAÇÃO de MARIA LETICIA DE OLIVEIRA LYRA, discente regular do Programa de Pós-Graduação em Biologia Geral e Aplicada, Curso de Mestrado Acadêmico;

+ #strong[19-11-2025] Membro da Comissão Examinadora da DEFESA DE DISSERTAÇÃO de MATHEUS RODRIGUES SAUDA, discente regular do Programa de Pós-Graduação em Ciências Biológicas (Genética), Curso de Mestrado Acadêmico;

+ #strong[08-01-2026] Membro da Comissão Examinadora da DEFESA DE DISSERTAÇÃO de LUISA ANNIBAL BARATA, discente regular do Programa de Pós-Graduação em Biologia Geral e Aplicada, Curso de Mestrado Acadêmico;

+ #strong[24-02-2026] MEMBRO TITULAR da Comissão Examinadora da DEFESA DE DISSERTAÇÃO de MARIANA ANTUNES PELEGATI, discente regular do Programa de PósGraduação em Biometria, Curso de Mestrado Acadêmico;

+ #strong[16-07-2026] MEMBRO TITULAR da Comissão Examinadora do Exame de QUALIFICAÇÃO de TAINÁ DORTE DA SILVA, discente regular do Programa de Pós Graduação em Biologia Geral e Aplicada, Curso de Doutorado Acadêmico;

+ #strong[12-08-2026] MEMBRO TITULAR da Comissão Examinadora da 1ª Banca de Acompanhamento de DOUTORADO da aluna Isabelle Mira da Silva matriculada no Programa de Pós-Graduação em Cirurgia e Medicina Translacional - FMB - UNESP;

== Cursos, Seminários e Palestras Ministradas
<cursos-seminários-e-palestras-ministradas>
Esta seção reúne os cursos, seminários e palestras ministrados ao longo da trajetória acadêmica e profissional, em diferentes contextos institucionais e científicos. As atividades aqui descritas refletem a atuação na difusão do conhecimento, na formação de estudantes e profissionais, bem como na troca de experiências com a comunidade acadêmica e científica, abrangendo ações de caráter didático, técnico e científico, realizadas em âmbito presencial e remoto.

=== Palestras
<palestras>
+ FERREIRA, M.R. #emph[Física das radiações];, #strong[2022];. Evento: Curso de Medicina Veterinária da Faculdade Galileu de Botucatu; Modalidade: #strong[Online];.

+ FERREIRA, MR. #emph[Bioinformática];, #strong[2022];. Evento: Disciplina de "Técnicas Especiais aplicadas à Pesquisa em Patologia" junto ao Programa de Pós-Graduação em Patologia da Faculdade de Medicina de Botucatu -- UNESP; Modalidade: #strong[Online];.

+ FERREIRA, MR. #emph[Reanálise de datasets - pipelines e serviços];, #strong[2023];. Evento: Disicplina de Noções Básicas e Aplicações da Bioinformática, do Programa de Pós-graduação em Biologia Geral e Aplicada; Modalidade: #strong[Presencial];.

+ FERREIRA, MR. #emph[Mesa-redonda: Internacionalização em Biotecnologia];, #strong[2023];. Evento: VIII Workshop de Biotecnologia, organizado pelos alunos de Pós-graduação em Biotecnologia, da Universidade Estadual Paulista "Júlio de Mesquita Filho"; Modalidade: #strong[Online];;

+ FERREIRA, MR. #emph[Desvendando os Segredos dos Dados Biológicos: O Poder da Bioinformática];, #strong[2024];. Evento: Programa de Pós-Graduação em Biometria da Universidade Estadual Paulista "Júlio de Mesquita Filho" -- UNESP; Modalidade: #strong[Presencial];.

+ FERREIRA, M. R. #emph[Biotecnologia forense: Bioinformática aplicada na identificação humana por DNA];, #strong[2024];. Evento: I Workshop de Engenharia de Bioprocessos e Biotecnologia (WEBB); Modalidade: #strong[Presencial];.

+ FERREIRA, M. R. #emph[Bioinformática: Perspectivas para Físicos Médicos];, #strong[2024];. Evento: XVIII CONFIAM - Congresso de Física Aplicada à Medicina; Modalidade: #strong[Presencial];.

+ FERREIRA, MR. #emph[Inteligência Artificial e o Futuro da Pesquisa: Desafios e Oportunidades];, #strong[2025];. Evento: IX Congresso de Pesquisa e Iniciação Científica - VI Congresso de Pós-graduação e III Encontro de Práticas Extensionistas da FAFIPE/FUNEPE, promovido pela Faculdade de Filosofia, Ciências e Letras de Penápolis (FAFIPE), mantida pela Fundação Educacional de Penápolis (FUNEPE); Modalidade: #strong[Presencial];.

+ FERREIRA, MR. Desafios e Perspectivas do Sequenciamento de Terceira Geração na Genética Forense, #strong[2026];. XVIII Curso de Inverno em Genética; Modalidade: #strong[Presencial];.

+ FERREIRA, MR. Short and Long reads Oxford Nanopore- diferenças nos bancos de dados e analises, #strong[2026];. Evento: Disicplina de Noções Básicas e Aplicações da Bioinformática, do Programa de Pós-graduação em Biologia Geral e Aplicada; Modalidade: #strong[Presencial];.

=== Cursos ministrados
<cursos-ministrados>
+ #underline[#strong[FERREIRA, M. R.];];. #emph[Acelerando sua análise de dados com tidyverse];, #strong[2024];. Evento: XXI Workshop de Genética (Curso de curta duração ministrado).

+ #underline[#strong[FERREIRA, Marcel Rodrigues];];; RECALDE, T. F.; CASTELLI, E. C.; MENDES JUNIOR, C. T. Curso de Difusão - #emph[Bioinformática aplicada à genética forense: análise de dados de sequenciamento de segunda e terceira geração,] #strong[2024];. (Curso de curta duração ministrado)

+ #underline[#strong[FERREIRA, M. R.];];. #emph[Desvendando os Segredos da Visualização de dados: ggplot2 para Iniciantes];, #strong[2024];. Evento: XIII Congresso de Biociências (Congrebio). (Curso de curta duração ministrado)

+ #underline[#strong[FERREIRA, M. R];];.; MENDES JUNIOR, C. T.; CASTELLI, E. C.; RECALDE, T. F.. #emph[Bioinformática aplicada à genética forense: análise de dados de sequenciamento de segunda e terceira geração];, #strong[2023];. (Curso de curta duração ministrado)

== Organização de Eventos
<organização-de-eventos>
+ FERREIRA, M. R. III Workbiotech: Workshop da Pós Graduação em Biotecnologia II Symposium on Cellular Dynamics: Building Insights and Breaking Boundaries., 2017. (Organização de evento)

+ OLIVEIRA NETO, M.; FERREIRA, M. R.. II Workshop de Biotecnologia, 2016.

+ FERREIRA, M. R.. MINICURSO DE LATEX, 2014.

+ FERREIRA, M. R.. X CONFIAM - Congresso de Física Aplicada à Medicina, 2014.

+ FERREIRA, M. R.. ANÁLISE DE DADOS COM PLANILHA ELETRÔNICA, 2013.

== Assessor Ad-hoc: Agências de Fomento, Instituições Acadêmicas, e Avaliação de Artigos para Periódicos Nacionais e Internacionais
<assessor-ad-hoc-agências-de-fomento-instituições-acadêmicas-e-avaliação-de-artigos-para-periódicos-nacionais-e-internacionais>
Ao longo da minha trajetória acadêmica, venho atuando como assessor ad hoc para periódicos científicos nacionais e internacionais, contribuindo para a avaliação crítica de manuscritos nas áreas de biologia celular, bioengenharia, toxicologia e ciências biomédicas. Essa atuação reflete o reconhecimento da minha formação técnica e da minha experiência científica pela comunidade acadêmica, além de demonstrar minha capacidade de análise crítica, rigor metodológico e compromisso com a qualidade da produção científica.

#line(length: 50%, stroke: white)
=== Avaliação de Artigos para Periódicos Nacionais e Internacionais
<avaliação-de-artigos-para-periódicos-nacionais-e-internacionais>
+ #link("https://link.springer.com/journal/40001")[European Journal of Medical Research] - Desde 2025 (01 parecer);

+ #link("https://link.springer.com/journal/10565")[Cell Biology and Toxicology] - Desde 2024 (02 pareceres);

+ #link("https://www.nature.com/srep/")[Scientific Reports] - Desde 2024 (04 pareceres);

+ #link("https://www.sciencedirect.com/journal/life-sciences")[Life Sciences] - Desde 2023 (01 parecer);

+ #link("https://www.frontiersin.org/journals/bioengineering-and-biotechnology")[Frontiers in Bioengineering and Biotechnology] - Desde 2023 (01 parecer);

+ #link("https://link.springer.com/journal/12860")[BMC Molecular and Cell Biology] - Desde 2023 (01 parecer);

+ #link("https://www.sciencedirect.com/journal/international-journal-of-biological-macromolecules")[International Journal of Biological Macromolecules] - Desde 2025 (01 parecer);

+ #link("https://www.nature.com/npjprecisiononcology/")[npj Precision Oncology] - Desde 2026 (01 parecer);

+ #link("https://link.springer.com/journal/40199")[DARU Journal of Pharmaceutical Sciences] - Desde 2026 (01 parecer);

+ #link("https://www.frontiersin.org/journals/genetics")[Frontiers in Genetics] - Desde 2026 (01 parecer);

#line(length: 50%, stroke: white)
=== Assessorias Técnicas e Avaliações Institucionais
<assessorias-técnicas-e-avaliações-institucionais>
+ SEBRAE -- Avaliador do Prêmio Startup do Futuro (2022-2023).

#pagebreak()
= Atividades Administrativas
<sec-8>
Considerando o estágio atual da minha trajetória acadêmica, ainda concentro minhas atividades principalmente em ensino, pesquisa e extensão. No entanto, já atuei em atividades administrativas e de representação institucional, destacando-se a participação como membro discente do Conselho do Programa de Pós-Graduação em Biotecnologia, no período de 08/03/2017 a 07/03/2018, exercendo a função de representante discente. Essa experiência contribuiu para a compreensão dos processos de gestão acadêmica e para o desenvolvimento de uma atuação responsável em instâncias colegiadas.

#pagebreak()
= Nomenclatura para Lista de Anexos
<sec-9>
A lista de anexos, bem como os respectivos arquivos digitais, seguirá a mesma numeração das seções deste documento às quais os anexos se referem. Dessa forma, cada anexo será identificado pelo número da seção correspondente. Por exemplo, os documentos relativos à seção 6.4 --- "#emph[Publicações: Artigos Completos Aceitos para Publicação e Publicados em Periódicos Internacionais, Capítulos de Livros Publicados e Trabalhos Completos Publicados em Anais de Congressos];" --- serão identificados como Anexo 6.4 e salvos como `anexo_6.4.xx.pdf`. Esse padrão de nomenclatura tem como objetivo facilitar a organização, a rastreabilidade e o processo de verificação das informações apresentadas.

#pagebreak()
= Considerações Finais
<sec-10>
Ao longo deste memorial, apresentei os principais aspectos da minha trajetória acadêmica e profissional, marcada pelo aprendizado contínuo, pela colaboração e pelo compromisso com a produção e a disseminação do conhecimento. Reconheço que essa trajetória foi construída de forma coletiva e, por isso, agradeço aos professores, servidores e colegas com quem tive a oportunidade de conviver ao longo dos anos, cujas contribuições foram essenciais para minha formação e desenvolvimento.

#pagebreak()
= Bibliografia
<bibliografia>
#block[
#block[
Alon, Uri. 2009. “How To Choose a Good Scientific Problem”. #emph[Molecular Cell] 35 (6): 726--28. #link("https://doi.org/10.1016/j.molcel.2009.09.013");.

] <ref-alon2009>
#block[
Alvarez, Thabata Maria, Marcelo Vizoná Liberato, João Paulo L. Franco Cairo, Douglas A. A. Paixão, Bruna M. Campos, Marcel R. Ferreira, Rodrigo F. Almeida, et al. 2015. “A Novel Member of GH16 Family Derived from Sugarcane Soil Metagenome”. #emph[Applied Biochemistry and Biotechnology] 177 (2): 304--17. #link("https://doi.org/10.1007/s12010-015-1743-7");.

] <ref-Alvarez2015>
#block[
Bezerra, Fabio Fábio, Marcel R. Ferreira, Giselle N. G. N. Fontes, Célio Jr C. J. da Costa Fernandes, D. C. Denise C. Andia, Nilson C. N. C. Cruz, Rodrigo A. R. A. da Silva, et al. 2017. “Nano hydroxyapatite-blasted titanium surface affects pre-osteoblast morphology by modulating critical intracellular pathways”. #emph[Biotechnology and Bioengineering] 114 (8): 1888--98. #link("https://doi.org/10.1002/bit.26310");.

] <ref-bezerra2017>
#block[
Castelli, Erick C., Raphaela Neto Pereira, Gabriela Sato Paes, Heloisa S. Andrade, Marcel Rodrigues Ferreira, Ícaro Scalisse de Freitas Santos, Nicolas Vince, Nicholas R. Pollock, Paul J. Norman, e Diogo Meyer. 2025. “Kir-Mapper: A Toolkit for Killer-Cell Immunoglobulin-Like Receptor (KIR) Genotyping From Short-Read Second-Generation Sequencing Data”. #emph[HLA] 105 (3). #link("https://doi.org/10.1111/tan.70092");.

] <ref-Castelli2025>
#block[
Fernandes, Célio J.C., Fábio Bezerra, Marcel R. Ferreira, Amanda F. C. Andrade, Thais Silva Pinto, e Willian F. Zambuzzi. 2018. “Nano Hydroxyapatite-Blasted Titanium Surface Creates a Biointerface Able to Govern Src-Dependent Osteoblast Metabolism as Prerequisite to ECM Remodeling”. #emph[Colloids and Surfaces B: Biointerfaces] 163 (março): 321--28. #link("https://doi.org/10.1016/j.colsurfb.2017.12.049");.

] <ref-Fernandes2018>
#block[
Ferreira, Marcel. 2025. “tidyspec: Spectroscopy Analysis Using the Tidy Data Philosophy”. #link("https://CRAN.R-project.org/package=tidyspec");.

] <ref-tidyspec>
#block[
Ferreira, Marcel Rodrigues, Geórgia da Silva Feltran, Anderson Moreira Gomes, José Cavalcante Souza Vieira, Guilherme Gazolla Santana, Matheus Amaral Silva, Emerson Araújo Alves dos Santos, e Willian Fernando Zambuzzi. 2025. “Mesenchymal Stem Cell Differentiation Induced by Lyophilized PRP During Early Osteogenesis”. #emph[Cell Biology International] 50 (1). #link("https://doi.org/10.1002/cbin.70101");.

] <ref-Ferreira2026>
#block[
Ferreira, Marcel Rodrigues, Renato Milani, Elidiane C. Rangel, Maikel Peppelenbosch, e Willian Zambuzzi. 2020. “OsteoBLAST: Computational Routine of Global Molecular Analysis Applied to Biomaterials Development”. #emph[Frontiers in Bioengineering and Biotechnology] 8 (outubro). #link("https://doi.org/10.3389/fbioe.2020.565901");.

] <ref-ferreira2020>
#block[
Ferreira, Marcel Rodrigues, e Willian Fernando Zambuzzi. 2021. “Platelet microparticles load a repertory of miRNAs programmed to drive osteogenic phenotype”. #emph[Journal of Biomedical Materials Research Part A] 109 (8): 1502--11. #link("https://doi.org/10.1002/jbm.a.37140");.

] <ref-ferreira2021>
#block[
Ferreira, Marcel R., Gerson A. Santos, Carlos A. Biagi, Wilson A. Silva Junior, e Willian F. Zambuzzi. 2020. “GSVA score reveals molecular signatures from transcriptomes for biomaterials comparison”. #emph[Journal of Biomedical Materials Research - Part A] 109 (March): 1--11. #link("https://doi.org/10.1002/jbm.a.37090");.

] <ref-ferreira2020a>
#block[
Franco Cairo, João Paulo L., Fernanda Mandelli, Robson Tramontina, David Cannella, Alessandro Paradisi, Luisa Ciano, Marcel R. Ferreira, et al. 2022. “Oxidative Cleavage of Polysaccharides by a Termite-Derived #emph[Superoxide Dismutase] Boosts the Degradation of Biomass by Glycoside Hydrolases”. #emph[Green Chemistry] 24 (12): 4845--58. #link("https://doi.org/10.1039/d1gc04519a");.

] <ref-Franco2022>
] <refs>
#pagebreak()
#block[
#heading(
level: 
2
, 
numbering: 
none
, 
[
ANEXOS
]
)
]



